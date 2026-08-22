locals {
  code_runner_function_name = "${var.app_name}-code-runner"

  # IAM ポリシーが関数 ARN を参照し、関数が実行ロールを参照するため、両者を直接つなぐと
  # 循環参照になる。関数名は決定論的なので ARN を文字列で組み立てて断ち切る。
  #
  # 関数名を決定論的にしておく必要はもう 1 つある。terraform/ecs.tf の
  # ignore_changes = [container_definitions] により、タスク定義に環境変数を足しても本番へ
  # 反映されない。そのため Rails 側は関数名を環境変数ではなく config.x の定数で持つ (#322)。
  code_runner_function_arn = "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${local.code_runner_function_name}"
}

# ============================================================
# 関数コードの zip
# ============================================================
#
# CI ではなく Terraform でコードを管理する。サンドボックスの変更頻度は極めて低く、
# drift 源を増やしたくないため (ECS タスク定義のドリフトが構造的に再発している前例がある)。
# GitHub Actions ロールへの IAM 権限追加も不要になる。
# 頻繁に変えるフェーズに入ったら update-function-code + ignore_changes 方式に移行する。
data "archive_file" "code_runner" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/code_runner/ruby"
  output_path = "${path.module}/.build/code_runner.zip"

  # テスト用のファイルは本番の zip に含めない。
  # ハンドラ本体は stdlib のみで動くので gem の同梱も不要。
  excludes = ["spec", "Gemfile", "Gemfile.lock", ".rspec"]
}

# ============================================================
# Lambda 関数
# ============================================================
resource "aws_lambda_function" "code_runner" {
  function_name = local.code_runner_function_name
  role          = aws_iam_role.code_runner.arn

  # handler.rb が zip のルートに来るので handler.lambda_handler。
  handler = "handler.lambda_handler"

  # ruby3.4 のサポート期限は 2028-03-31。ruby3.2 は 2026-03-31 に非推奨化済み、
  # ruby3.3 は 2027-03-31 で残りが短い。
  #
  # ★ ruby4.x に上げるときは fiddle がランタイムに含まれているか必ず確認すること。
  #   handler.rb の PR_SET_DUMPABLE 保護は fiddle に依存しており、fiddle は Ruby 4.0 で
  #   default gem から外れる。詳細は lambda/code_runner/README.md を参照。
  runtime = "ruby3.4"

  # GB-秒単価が x86 比で安く、既存の EC2 (t4g.micro) や CI のビルドとも整合する。
  architectures = ["arm64"]

  memory_size                    = var.code_runner_memory_mb
  timeout                        = var.code_runner_timeout_seconds
  reserved_concurrent_executions = var.code_runner_reserved_concurrency

  filename         = data.archive_file.code_runner.output_path
  source_code_hash = data.archive_file.code_runner.output_base64sha256

  # 経路を持たない専用サブネットと、ingress/egress ゼロの SG に閉じ込める。
  # これによりインターネット・RDS・AWS API のすべてに到達できなくなる。
  vpc_config {
    subnet_ids         = [aws_subnet.sandbox_a.id, aws_subnet.sandbox_c.id]
    security_group_ids = [aws_security_group.code_runner.id]
  }

  # 環境変数は 1 つも渡さない。
  # ユーザーコードは unsetenv_others で環境を落とした上で起動されるが、そもそも
  # ハンドラ側に秘密を置かないのが前提 (CODE_RUNNER_TMP_ROOT はテスト専用で、本番は /tmp 既定)。

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.code_runner.name
  }

  # 実行ロールのポリシーより先に関数が起動するとログ配信が落ちるため、明示的に順序を付ける。
  depends_on = [
    aws_cloudwatch_log_group.code_runner,
    aws_iam_role_policy.code_runner,
  ]

  tags = {
    Name = local.code_runner_function_name
  }
}

# ============================================================
# リソースベースポリシー (invoke 元の明示)
# ============================================================
#
# ★ 同一アカウント内では、identity ベースのポリシーで許可されていれば invoke は通る。
#   つまりこれ単体で「ECS タスクロールだけに限定」できるわけではない。
#   目的は (1) invoke 元の意図をコード上に残すこと (2) クロスアカウントからの invoke を
#   遮断すること の 2 つである。実質的な限定は IAM 側 (aws_iam_role_policy の Resource 限定) が担う。
resource "aws_lambda_permission" "ecs_task_invoke" {
  statement_id  = "AllowInvokeFromEcsTaskRole"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.code_runner.function_name
  principal     = aws_iam_role.ecs_task.arn
}

resource "aws_lambda_permission" "warmup_invoke" {
  statement_id  = "AllowInvokeFromWarmupScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.code_runner.function_name
  principal     = aws_iam_role.code_runner_warmup.arn
}

# ============================================================
# 日次ウォームアップ
# ============================================================
#
# VPC 接続の副作用への対処。14 日アイドルすると Hyperplane ENI が回収されて関数が Inactive
# になり、次の呼び出しが失敗する (AWS 公式が明記)。1 日 1 回 invoke して回収を防ぐ。
# ハンドラ側は {"warmup": true} を受け取るとユーザーコードの実行経路に入らず即座に返すので、
# コストは実質ゼロ。
resource "aws_scheduler_schedule" "code_runner_warmup" {
  name        = "${var.app_name}-code-runner-warmup"
  description = "Keeps the VPC-attached code_runner from going Inactive after 14 idle days"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "rate(1 day)"
  schedule_expression_timezone = "Asia/Tokyo"

  target {
    arn      = aws_lambda_function.code_runner.arn
    role_arn = aws_iam_role.code_runner_warmup.arn
    input    = jsonencode({ warmup = true })

    # ENI 保持が目的なので、失敗しても次の日にまた投げれば足りる。
    retry_policy {
      maximum_retry_attempts = 0
    }
  }
}
