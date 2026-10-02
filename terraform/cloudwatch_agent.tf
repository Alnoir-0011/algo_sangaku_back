# ============================================================
# EC2 ディスク使用率監視 (CloudWatch Agent)
# ============================================================
# EC2 の標準メトリクスにはディスク使用率が含まれないため、CloudWatch Agent を
# SSM Association で既存の EC2 に後付け配布する。user_data に組み込む方式は
# EC2 起動時にしか実行されず、変更の反映には terraform taint 等による EC2 の
# 再作成 (ダウンタイム発生) が必要になるため避けている。

# drop_device = true により device/fstype の dimension を落とし、InstanceId + path
# のみに固定する。これにより下の aws_cloudwatch_metric_alarm の dimensions を
# Agent 起動後の実際のデバイス名 (nvme0n1p1 等、AMI 依存で事前に確定できない) に
# 依存せず書ける。InstanceId の dimension 付与には append_dimensions が必須
# (デフォルトでは付与されない)。
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name = "/${var.app_name}/cloudwatch-agent/config"
  type = "String"
  value = jsonencode({
    metrics = {
      namespace = "CWAgent"
      append_dimensions = {
        InstanceId = "$${aws:InstanceId}"
      }
      metrics_collected = {
        disk = {
          measurement = ["used_percent"]
          resources   = ["/"]
          drop_device = true
        }
      }
    }
  })

  tags = { Name = "${var.app_name}-cloudwatch-agent-config" }
}

# CloudWatch Agent が設定を取得し、メトリクスを送信するための最小権限。
# ssm:GetParameter は CloudWatch Agent 設定専用のパラメータ名のみに制限し、
# Parameter Store 全体が読める AmazonSSMManagedInstanceCore を使わない既存方針
# (terraform/iam.tf の ecs_instance_ssm 参照) を維持する。
data "aws_iam_policy_document" "ecs_instance_cloudwatch_agent" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.cloudwatch_agent_config.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["CWAgent"]
    }
  }

  # AWS-ConfigureAWSPackage (Distributor) 経由での CloudWatch Agent 本体のインストールに
  # 必要な権限。ECS-optimized AMI には Agent が標準導入されていないため別途インストールが
  # 要る。SSM Agent バージョン 2.2.45.0 以降は <region>-birdwatcher-prod バケットを、
  # それより前のバージョンは amazon-ssm-packages-<region> バケットを参照するため両方許可する。
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetManifest",
      "ssm:PutInventory",
      "ssm:PutConfigurePackageResult",
    ]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${var.aws_region}-birdwatcher-prod/*",
      "arn:aws:s3:::amazon-ssm-packages-${var.aws_region}/*",
    ]
  }
}

resource "aws_iam_role_policy" "ecs_instance_cloudwatch_agent" {
  name   = "${var.app_name}-ecs-instance-cloudwatch-agent"
  role   = aws_iam_role.ecs_instance.id
  policy = data.aws_iam_policy_document.ecs_instance_cloudwatch_agent.json
}

# ECS-optimized AMI (Amazon Linux 2023) には CloudWatch Agent が標準導入されていないため、
# AmazonCloudWatch-ManageAgent (設定適用) の前提として Distributor 経由でインストールする。
resource "aws_ssm_association" "cloudwatch_agent_install" {
  name = "AWS-ConfigureAWSPackage"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.main.id]
  }

  parameters = {
    action = "Install"
    name   = "AmazonCloudWatchAgent"
  }

  depends_on = [aws_iam_role_policy.ecs_instance_cloudwatch_agent]
}

resource "aws_ssm_association" "cloudwatch_agent" {
  name = "AmazonCloudWatch-ManageAgent"

  # デフォルトでは作成時に一度だけ適用され、Agent プロセスのクラッシュや EC2 再起動後に
  # 自動で再適用されない。30分ごとに再適用することで Agent の停止を自動的に復旧させる。
  schedule_expression = "rate(30 minutes)"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.main.id]
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = aws_ssm_parameter.cloudwatch_agent_config.name
    optionalRestart               = "yes"
  }

  depends_on = [
    aws_iam_role_policy.ecs_instance_cloudwatch_agent,
    aws_ssm_association.cloudwatch_agent_install,
  ]
}

resource "aws_cloudwatch_metric_alarm" "ec2_disk_used_percent" {
  alarm_name        = "${var.app_name}-ec2-disk-used-percent"
  alarm_description = "EC2 ${aws_instance.main.id} のディスク使用率 (/) が 80% を超えました"
  namespace         = "CWAgent"
  metric_name       = "disk_used_percent"
  # drop_device は device dimension のみを除去し、fstype は残る。CloudWatch アラームは
  # dimension の完全一致が必要なため、実際に発行されたメトリクス (本番 EC2 で確認した
  # fstype=xfs, Amazon Linux 2023 の既定ファイルシステム) に合わせて指定する。AMI を
  # 変更してファイルシステムが変わった場合はこの値も見直すこと。
  dimensions = {
    InstanceId = aws_instance.main.id
    path       = "/"
    fstype     = "xfs"
  }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  # Agent 自体が配布・起動に失敗してメトリクスが来ない状態も異常として検知する。
  treat_missing_data = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.app_name}-ec2-disk-used-percent-alarm" }
}
