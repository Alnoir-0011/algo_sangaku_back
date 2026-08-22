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

# Lambda code_runner のログ。
#
# Terraform で先に作るのが要点。実行ロールに logs:CreateLogGroup を付けずに済ませるためで、
# 関数側の logging_config でこのロググループを明示する。
# 保持期間が ECS より短いのは、採点のたびに出るだけで長期保存する価値が無いため。
resource "aws_cloudwatch_log_group" "code_runner" {
  name              = "/aws/lambda/${local.code_runner_function_name}"
  retention_in_days = 7

  tags = { Name = "${var.app_name}-code-runner-logs" }
}
