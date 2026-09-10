resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  tags = {
    Name = "${var.app_name}-cluster"
  }
}

# ============================================================
# タスク定義 (3コンテナ: nginx / web / queue)
# ============================================================
resource "aws_ecs_task_definition" "main" {
  family                   = var.app_name
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    # --- web (Rails/Puma) ---
    {
      name  = "web"
      image = "${aws_ecr_repository.rails.repository_url}:${var.initial_image_tag}"
      essential = true

      entryPoint = ["/algo_sangaku_back/entrypoint.sh"]
      command    = ["bundle", "exec", "puma", "-C", "config/puma.rb"]

      # portMappings は指定しない: nginx からは links による内部到達で十分であり、
      # bridge モードで hostPort を省略すると EC2 ホストの全インターフェースに
      # ephemeral ポートで公開されてしまう (CloudFront シークレット検証を迂回できてしまう)
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      secrets = [
        { name = "RAILS_MASTER_KEY",        valueFrom = aws_ssm_parameter.rails_master_key.arn },
        { name = "POSTGRES_HOST",           valueFrom = aws_ssm_parameter.postgres_host.arn },
        { name = "POSTGRES_USER",           valueFrom = aws_ssm_parameter.postgres_user.arn },
        { name = "POSTGRES_PASSWORD",       valueFrom = aws_ssm_parameter.postgres_password.arn },
        { name = "POSTGRES_DB",             valueFrom = aws_ssm_parameter.postgres_db.arn },
        { name = "GOOGLE_CLIENT_ID",         valueFrom = aws_ssm_parameter.google_client_id.arn },
        { name = "GOOGLE_MAP_API_KEY",       valueFrom = aws_ssm_parameter.google_map_api_key.arn },
        { name = "PAIZAIO_API_KEY",           valueFrom = aws_ssm_parameter.paizaio_api_key.arn },
        { name = "OPENAI_API_KEY",          valueFrom = aws_ssm_parameter.openai_api_key.arn },
        { name = "FRONTEND_URL",            valueFrom = aws_ssm_parameter.frontend_url.arn },
        { name = "CLIENT_SECRET",           valueFrom = aws_ssm_parameter.client_secret.arn },
      ]

      environment = [
        { name = "RAILS_ENV",            value = "production" },
        { name = "RAILS_LOG_TO_STDOUT",  value = "true" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_web.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "web"
        }
      }

      memory = 600
    },

    # --- nginx ---
    {
      name  = "nginx"
      image = "${aws_ecr_repository.nginx.repository_url}:${var.initial_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      # web コンテナに TCP (127.0.0.1 ではなく bridge 内の web:3000) で到達するためのリンク
      # network_mode が awsvpc ではないため、コンテナ間通信には links による名前解決が必要
      links = ["web"]

      # 実際のリクエスト経路 (nginx -> web) を検査し、ヘルスチェックのすり抜けを防ぐ。
      # 127.0.0.1:8081 のループバック専用エンドポイント (nginx.conf.template) を叩くため、
      # CLOUDFRONT_SECRET をコマンド引数に含めない (argv 露出やフェイルオープン誤検知を回避)
      healthCheck = {
        command     = ["CMD-SHELL", "curl -fsS http://127.0.0.1:8081/up || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      dependsOn = [
        {
          containerName = "web"
          condition     = "HEALTHY"
        }
      ]

      secrets = [
        { name = "CLOUDFRONT_SECRET", valueFrom = aws_ssm_parameter.cloudfront_secret.arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_nginx.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx"
        }
      }

      memory = 96
    },

    # --- queue (Solid Queue) ---
    {
      name  = "queue"
      image = "${aws_ecr_repository.rails.repository_url}:${var.initial_image_tag}"
      essential = false

      entryPoint = ["/algo_sangaku_back/entrypoint-queue.sh"]
      command    = ["bundle", "exec", "ruby", "bin/jobs"]

      dependsOn = [
        {
          containerName = "web"
          condition     = "HEALTHY"
        }
      ]

      secrets = [
        { name = "RAILS_MASTER_KEY",        valueFrom = aws_ssm_parameter.rails_master_key.arn },
        { name = "POSTGRES_HOST",           valueFrom = aws_ssm_parameter.postgres_host.arn },
        { name = "POSTGRES_USER",           valueFrom = aws_ssm_parameter.postgres_user.arn },
        { name = "POSTGRES_PASSWORD",       valueFrom = aws_ssm_parameter.postgres_password.arn },
        { name = "POSTGRES_DB",             valueFrom = aws_ssm_parameter.postgres_db.arn },
        { name = "GOOGLE_CLIENT_ID",        valueFrom = aws_ssm_parameter.google_client_id.arn },
        { name = "GOOGLE_MAP_API_KEY",      valueFrom = aws_ssm_parameter.google_map_api_key.arn },
        { name = "PAIZAIO_API_KEY",         valueFrom = aws_ssm_parameter.paizaio_api_key.arn },
        { name = "OPENAI_API_KEY",          valueFrom = aws_ssm_parameter.openai_api_key.arn },
        { name = "FRONTEND_URL",            valueFrom = aws_ssm_parameter.frontend_url.arn },
        { name = "CLIENT_SECRET",           valueFrom = aws_ssm_parameter.client_secret.arn },
      ]

      environment = [
        { name = "RAILS_ENV",            value = "production" },
        { name = "RAILS_LOG_TO_STDOUT",  value = "true" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_queue.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "queue"
        }
      }

      memory = 600
    }
  ])

  tags = {
    Name = "${var.app_name}-task"
  }

  # GitHub Actions のデプロイフローがコンテナイメージを管理するため、
  # terraform apply でブートストラップ用のイメージタグに巻き戻らないよう無視する
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

# ============================================================
# ECS サービス
# ============================================================
resource "aws_ecs_service" "main" {
  name                   = "${var.app_name}-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.main.arn
  desired_count          = 1
  launch_type            = "EC2"
  enable_execute_command = true

  # 単一 EC2 のためダウンタイムを許容してデプロイ (ASG なし構成の制約)
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  tags = {
    Name = "${var.app_name}-service"
  }

  # GitHub Actions がデプロイのたびにタスク定義リビジョンを更新するため、
  # terraform apply でサービスが古いリビジョンに戻らないよう無視する
  lifecycle {
    ignore_changes = [task_definition]
  }
}
