resource "aws_cloudwatch_log_group" "ecs_web" {
  name              = "/ecs/${var.app_name}/web"
  retention_in_days = 30

  tags = { Name = "${var.app_name}-ecs-web-logs" }
}

resource "aws_cloudwatch_log_group" "ecs_nginx" {
  name              = "/ecs/${var.app_name}/nginx"
  retention_in_days = 30

  tags = { Name = "${var.app_name}-ecs-nginx-logs" }
}

resource "aws_cloudwatch_log_group" "ecs_queue" {
  name              = "/ecs/${var.app_name}/queue"
  retention_in_days = 30

  tags = { Name = "${var.app_name}-ecs-queue-logs" }
}

# ============================================================
# 通知経路
# ============================================================
resource "aws_sns_topic" "alerts" {
  name = "${var.app_name}-alerts"

  tags = { Name = "${var.app_name}-alerts" }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================
# Rails のアプリ障害検知
# ============================================================
# render_500 (app/controllers/concerns/api/exception_handler.rb) が
# rescue_from StandardError の受け皿として Rails.logger.error で出力する
# 本当のアプリ障害のみを対象とする。
#
# FATAL は意図的に対象外にしている: ActionController::RoutingError (存在しない
# パスへのアクセス) はコントローラの rescue_from より手前で発生するため捕捉されず、
# Rails 8.1 のデフォルト設定 (log_rescued_responses = true, debug_exception_log_level
# = :fatal) によりボット・スキャナーによる 404 アクセスがそのまま FATAL としてログに
# 出力される。FATAL を対象にするとそれらのノイズで鳴り続け、アラーム疲れを招く。
resource "aws_cloudwatch_log_metric_filter" "rails_error" {
  name           = "${var.app_name}-rails-error"
  log_group_name = aws_cloudwatch_log_group.ecs_web.name
  pattern        = "?ERROR"

  metric_transformation {
    name          = "RailsErrorCount"
    namespace     = "AlgoSangaku/Rails"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "rails_error" {
  alarm_name          = "${var.app_name}-rails-error"
  alarm_description   = "Rails アプリでエラーが発生しました (${aws_cloudwatch_log_group.ecs_web.name} の ERROR ログ)"
  namespace           = aws_cloudwatch_log_metric_filter.rails_error.metric_transformation[0].namespace
  metric_name         = aws_cloudwatch_log_metric_filter.rails_error.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.app_name}-rails-error-alarm" }
}

# queue コンテナ (Solid Queue, app/jobs/ 配下) のエラー検知。
# CorrectnessCheckJob 等のジョブはこのログループに出力されるため、ecs_web 向けの
# rails_error アラームでは拾われない。queue は Rails のリクエスト処理を経由しないため
# ActionController::RoutingError によるボットノイズの懸念がなく、FATAL も対象にしてよい。
resource "aws_cloudwatch_log_metric_filter" "queue_error" {
  name           = "${var.app_name}-queue-error"
  log_group_name = aws_cloudwatch_log_group.ecs_queue.name
  pattern        = "?ERROR ?FATAL"

  metric_transformation {
    name          = "QueueErrorCount"
    namespace     = "AlgoSangaku/Rails"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "queue_error" {
  alarm_name          = "${var.app_name}-queue-error"
  alarm_description   = "Solid Queue ジョブでエラーが発生しました (${aws_cloudwatch_log_group.ecs_queue.name} の ERROR/FATAL ログ)"
  namespace           = aws_cloudwatch_log_metric_filter.queue_error.metric_transformation[0].namespace
  metric_name         = aws_cloudwatch_log_metric_filter.queue_error.metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.app_name}-queue-error-alarm" }
}

# ============================================================
# ECS サービス停止検知
# ============================================================
# RunningTaskCount は ECS/ContainerInsights namespace 専用で Container Insights の
# 有効化が必須 (追加コスト発生・issue #335 では対象外)。Container Insights なしでも
# AWS/ECS namespace で標準発行される LiveTaskCount (ACTIVATING/RUNNING/DEACTIVATING
# 状態のタスク数) で代替する。
#
# aws_ecs_service.main は deployment_minimum_healthy_percent = 0 のため、デプロイ中に
# 一時的にタスク数が 0 になり得る。誤検知を避けるため 2 期間 (10分) 連続の閾値割れで
# 発火させる。
resource "aws_cloudwatch_metric_alarm" "ecs_service_down" {
  alarm_name        = "${var.app_name}-ecs-service-down"
  alarm_description = "ECS サービス ${aws_ecs_service.main.name} の稼働タスクが 0 になりました"
  namespace         = "AWS/ECS"
  metric_name       = "LiveTaskCount"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.main.name
  }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.app_name}-ecs-service-down-alarm" }
}

# ============================================================
# RDS 監視
# ============================================================
resource "aws_cloudwatch_metric_alarm" "rds_free_storage_space" {
  alarm_name        = "${var.app_name}-rds-free-storage-space"
  alarm_description = "RDS ${aws_db_instance.main.identifier} の空き容量が 2GB を下回りました"
  namespace         = "AWS/RDS"
  metric_name       = "FreeStorageSpace"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
  statistic = "Minimum"
  period    = 300
  # ストレージ枯渇は書き込み不能に直結し深刻度が高いため、他の新規アラーム (2期間連続)
  # と異なり意図的に 1 期間で即時発火させる。誤検知の懸念より検知の即時性を優先する。
  evaluation_periods  = 1
  threshold           = 2 * 1024 * 1024 * 1024
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.app_name}-rds-free-storage-space-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization" {
  alarm_name        = "${var.app_name}-rds-cpu-utilization"
  alarm_description = "RDS ${aws_db_instance.main.identifier} の CPU 使用率が 80% を超えました"
  namespace         = "AWS/RDS"
  metric_name       = "CPUUtilization"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.app_name}-rds-cpu-utilization-alarm" }
}

# db.t4g.micro (メモリ 1GiB) のデフォルトパラメータグループでの max_connections は
# LEAST({DBInstanceClassMemory/9531392}, 5000) で算出され 112 程度になる。その 80%
# (約90) を閾値とする。インスタンスクラスやパラメータグループを変更した場合は見直すこと。
resource "aws_cloudwatch_metric_alarm" "rds_database_connections" {
  alarm_name        = "${var.app_name}-rds-database-connections"
  alarm_description = "RDS ${aws_db_instance.main.identifier} の接続数が最大接続数の 80% 相当 (90) を超えました"
  namespace         = "AWS/RDS"
  metric_name       = "DatabaseConnections"
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 90
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.app_name}-rds-database-connections-alarm" }
}

# ============================================================
# EC2 監視
# ============================================================
resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  alarm_name        = "${var.app_name}-ec2-status-check-failed"
  alarm_description = "EC2 ${aws_instance.main.id} のステータスチェックが失敗しました"
  namespace         = "AWS/EC2"
  metric_name       = "StatusCheckFailed"
  dimensions = {
    InstanceId = aws_instance.main.id
  }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.app_name}-ec2-status-check-failed-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_utilization" {
  alarm_name        = "${var.app_name}-ec2-cpu-utilization"
  alarm_description = "EC2 ${aws_instance.main.id} の CPU 使用率が 80% を超えました"
  namespace         = "AWS/EC2"
  metric_name       = "CPUUtilization"
  dimensions = {
    InstanceId = aws_instance.main.id
  }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "${var.app_name}-ec2-cpu-utilization-alarm" }
}

# ============================================================
# ACM 証明書の期限切れ検知
# ============================================================
# ACM 証明書は CloudFront 用に us-east-1 で発行されている (terraform/acm.tf) ため、
# DaysToExpiry メトリクスも us-east-1 に存在する。CloudWatch アラームの alarm_actions
# には同一リージョンの SNS トピックしか指定できないため、us-east-1 専用の SNS トピックを
# 別途作成し、同じ送信先メールアドレスを subscribe する。
resource "aws_sns_topic" "alerts_us_east_1" {
  provider = aws.us_east_1
  name     = "${var.app_name}-alerts-us-east-1"

  tags = { Name = "${var.app_name}-alerts-us-east-1" }
}

resource "aws_sns_topic_subscription" "alerts_us_east_1_email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.alerts_us_east_1.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "acm_certificate_expiry" {
  provider          = aws.us_east_1
  alarm_name        = "${var.app_name}-acm-certificate-expiry"
  alarm_description = "ACM 証明書 ${aws_acm_certificate.main.domain_name} の有効期限が 30 日を切りました"
  namespace         = "AWS/CertificateManager"
  metric_name       = "DaysToExpiry"
  dimensions = {
    CertificateArn = aws_acm_certificate.main.arn
  }
  statistic           = "Minimum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 30
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.alerts_us_east_1.arn]
  ok_actions    = [aws_sns_topic.alerts_us_east_1.arn]

  tags = { Name = "${var.app_name}-acm-certificate-expiry-alarm" }
}
