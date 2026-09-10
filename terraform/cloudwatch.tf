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
