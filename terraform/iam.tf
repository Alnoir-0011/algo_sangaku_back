# ============================================================
# ECS EC2 インスタンスロール
# ============================================================
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance" {
  name               = "${var.app_name}-ecs-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# SSM Session Manager / Run Command で EC2 ホストに接続するための最小権限。
# ECS エージェントが接続不能になるとタスクが起動せず ECS Exec も使えなくなるため、
# ホスト側を調査する経路をタスクとは独立して確保しておく。
#
# マネージドポリシー AmazonSSMManagedInstanceCore は使わない。同ポリシーは
# ssm:GetParameter / GetParameters を Resource: "*" で含んでおり、Parameter Store の
# 全パラメータが読める。EC2 の IMDS は hop limit 2 でコンテナからも到達できるため、
# インスタンスロールが奪取された場合の被害を抑える目的で必要な権限のみに絞る。
data "aws_iam_policy_document" "ecs_instance_ssm" {
  # Session Manager のセッション確立
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }

  # Run Command (send-command) のメッセージ送受信
  statement {
    effect = "Allow"
    actions = [
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply",
    ]
    resources = ["*"]
  }

  # マネージドインスタンスとして登録・ハートビートするために必要
  statement {
    effect    = "Allow"
    actions   = ["ssm:UpdateInstanceInformation"]
    resources = ["*"]
  }

  # Run Command が実行する SSM ドキュメント (AWS-RunShellScript 等) の取得
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetDocument", "ssm:DescribeDocument"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecs_instance_ssm" {
  name   = "${var.app_name}-ecs-instance-ssm"
  role   = aws_iam_role.ecs_instance.id
  policy = data.aws_iam_policy_document.ecs_instance_ssm.json
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.app_name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

# ============================================================
# ECS タスクロール (ECS Exec / ssmmessages 用)
# ============================================================
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.app_name}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_exec" {
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecs_exec" {
  name   = "${var.app_name}-ecs-exec"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_exec.json
}

# Rails (CorrectnessCheckJob) から code_runner を呼ぶための権限。
# terraform/ecs.tf の通り web / queue は同じタスクロールを使うため、web からも invoke できる
# ことになる。Rails は既に DB へのフルアクセスを持っているので権限の増分としては小さい。
data "aws_iam_policy_document" "ecs_task_invoke_code_runner" {
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [local.code_runner_function_arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_invoke_code_runner" {
  name   = "${var.app_name}-ecs-task-invoke-code-runner"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_invoke_code_runner.json
}

# ============================================================
# ECS タスク実行ロール
# ============================================================
data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.app_name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SSM Parameter Store の読み取り権限
data "aws_iam_policy_document" "ecs_task_execution_ssm" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters", "ssm:GetParameter"]
    resources = ["arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.app_name}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${var.aws_region}:${var.aws_account_id}:alias/aws/ssm"]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_ssm" {
  name   = "${var.app_name}-ecs-task-execution-ssm"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_ssm.json
}

# ============================================================
# GitHub Actions OIDC 用 IAM
# ============================================================
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_oidc_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:production"]
    }
  }
}

resource "aws_iam_role" "github_actions_oidc" {
  name               = "${var.app_name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume_role.json
}

data "aws_iam_policy_document" "github_actions_deploy" {
  # ECR 認証トークン取得 (リソース制限不可のため "*")
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR リポジトリ操作 (対象リポジトリのみに制限)
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      # autodeploy.yml が同タグの存在確認・イメージダイジェスト取得に使用する
      "ecr:DescribeImages",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [
      aws_ecr_repository.rails.arn,
      aws_ecr_repository.nginx.arn,
    ]
  }

  # ECS タスク定義の登録・参照・一覧・deregister (いずれもリソース制限不可のため "*")
  statement {
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTaskDefinitions",
      "ecs:DeregisterTaskDefinition",
    ]
    resources = ["*"]
  }

  # ECS サービス操作 (対象クラスター・サービスのみに制限)
  statement {
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = [
      "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:cluster/${var.app_name}-cluster",
      "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:service/${var.app_name}-cluster/${var.app_name}-service",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn,
    ]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "${var.app_name}-github-actions-deploy"
  role   = aws_iam_role.github_actions_oidc.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}

# ============================================================
# Lambda code_runner 実行ロール
# ============================================================
#
# このロールは「奪われても無害であること」を目標に設計している。
# 子プロセスからの認証情報窃取は技術的には塞ぎきれない前提で（handler.rb の
# PR_SET_DUMPABLE は最終防衛線であって唯一の防壁ではない）、漏れても何もできない状態にする。
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "code_runner" {
  name               = "${var.app_name}-code-runner-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "code_runner" {
  # 自分のロググループへの書き込みのみ。logs:CreateLogGroup は付けない
  # (ロググループは aws_cloudwatch_log_group.code_runner で先に作ってある)。
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.code_runner.arn}:*"]
  }

  # VPC 接続の ENI 操作に必須。Lambda サービスが実行ロールの権限で代行するため、
  # ここを削ると関数が VPC に接続できない（CreateFunction / UpdateFunctionConfiguration が
  # "The provided execution role does not have permissions to call CreateNetworkInterface on
  # EC2" で失敗することを実測で確認済み）。
  #
  # ★ 対象をサンドボックスのサブネットと SG に限定するのが要点。
  #
  # 下の SourceFunctionArn 付き Deny は「実行環境の中からの呼び出し」にしか効かない。
  # ユーザーコードは /proc/<ppid>/environ から実行ロールの認証情報を読めてしまい
  # （本番の Lambda では prctl が seccomp に拒否され dumpable を落とせない）、
  # 盗んだ認証情報を外部で使うと条件キーが付かないので Deny が発動しない。
  # そのため Allow 側を絞っておかないと、アカウント全体の ENI を作成・削除できてしまう。
  statement {
    sid    = "CreateEniInSandboxOnly"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
    ]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:network-interface/*",
      aws_subnet.sandbox_a.arn,
      aws_subnet.sandbox_c.arn,
      aws_security_group.code_runner.arn,
    ]
  }

  # 削除はサンドボックスのサブネット内の ENI に限定する。
  # ここを "*" にすると、盗まれた認証情報でアカウント内の任意の ENI を削除できる。
  statement {
    sid       = "DeleteEniInSandboxOnly"
    effect    = "Allow"
    actions   = ["ec2:DeleteNetworkInterface"]
    resources = ["arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:network-interface/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:Subnet"
      values = [
        aws_subnet.sandbox_a.arn,
        aws_subnet.sandbox_c.arn,
      ]
    }
  }

  # Describe 系はリソースレベルの制限に対応していないため "*" のまま。
  # ENI 一覧の情報漏洩は残るが、破壊的な操作ではないため受け入れる。
  statement {
    sid       = "DescribeEni"
    effect    = "Allow"
    actions   = ["ec2:DescribeNetworkInterfaces"]
    resources = ["*"]
  }

  # 将来うっかり権限が足された場合の保険。logs と ec2 以外は明示的に拒否する。
  #
  # ★ NotAction に ec2:* を含めるのを外さないこと。issue #320 の記述どおり logs:* だけに
  #   すると、上の ENI 操作まで Deny されて関数が起動しなくなる。
  statement {
    effect      = "Deny"
    not_actions = ["logs:*", "ec2:*"]
    resources   = ["*"]
  }

  # ユーザーコード由来の ec2:* 呼び出しだけを拒否する。
  #
  # lambda:SourceFunctionArn は「関数の実行環境内から行われた呼び出し」に付く条件キーなので、
  # 実行環境の中で動くユーザーコードの呼び出しには付き、Lambda サービスが実行環境の外側で
  # 代行する ENI 操作には付かない。結果として ENI 作成は通り、ユーザーコードからの
  # ec2:* は落ちる。
  #
  # ★ 同じ手を logs:* に対しては使えない。CloudWatch Logs への配信も Lambda が実行環境の
  #   外側で代行するため、この条件キーで Deny するとログ配信ごと壊れる。
  statement {
    effect    = "Deny"
    actions   = ["ec2:*"]
    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "lambda:SourceFunctionArn"
      values   = [local.code_runner_function_arn]
    }
  }
}

resource "aws_iam_role_policy" "code_runner" {
  name   = "${var.app_name}-code-runner"
  role   = aws_iam_role.code_runner.id
  policy = data.aws_iam_policy_document.code_runner.json
}

# ============================================================
# EventBridge Scheduler (code_runner のウォームアップ用)
# ============================================================
data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "code_runner_warmup" {
  name               = "${var.app_name}-code-runner-warmup-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
}

data "aws_iam_policy_document" "code_runner_warmup" {
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [local.code_runner_function_arn]
  }
}

resource "aws_iam_role_policy" "code_runner_warmup" {
  name   = "${var.app_name}-code-runner-warmup"
  role   = aws_iam_role.code_runner_warmup.id
  policy = data.aws_iam_policy_document.code_runner_warmup.json
}
