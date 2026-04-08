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
