# ============================================================
# SSM Parameter Store (SecureString) で環境変数を一括管理
# ============================================================

locals {
  ssm_prefix = "/${var.app_name}"
}

resource "aws_ssm_parameter" "rails_master_key" {
  name  = "${local.ssm_prefix}/RAILS_MASTER_KEY"
  type  = "SecureString"
  value = var.rails_master_key

  tags = { Name = "${var.app_name}-rails-master-key" }
}

resource "aws_ssm_parameter" "cloudfront_secret" {
  name  = "${local.ssm_prefix}/CLOUDFRONT_SECRET"
  type  = "SecureString"
  value = var.cloudfront_secret_header_value

  tags = { Name = "${var.app_name}-cloudfront-secret" }
}

resource "aws_ssm_parameter" "postgres_host" {
  name  = "${local.ssm_prefix}/POSTGRES_HOST"
  type  = "SecureString"
  value = aws_db_instance.main.address

  tags = { Name = "${var.app_name}-postgres-host" }
}

resource "aws_ssm_parameter" "postgres_user" {
  name  = "${local.ssm_prefix}/POSTGRES_USER"
  type  = "String"
  value = var.db_username

  tags = { Name = "${var.app_name}-postgres-user" }
}

resource "aws_ssm_parameter" "postgres_password" {
  name  = "${local.ssm_prefix}/POSTGRES_PASSWORD"
  type  = "SecureString"
  value = var.db_password

  tags = { Name = "${var.app_name}-postgres-password" }
}

resource "aws_ssm_parameter" "postgres_db" {
  name  = "${local.ssm_prefix}/POSTGRES_DB"
  type  = "String"
  value = var.db_name

  tags = { Name = "${var.app_name}-postgres-db" }
}

resource "aws_ssm_parameter" "google_client_id" {
  name  = "${local.ssm_prefix}/GOOGLE_CLIENT_ID"
  type  = "SecureString"
  value = var.google_client_id

  tags = { Name = "${var.app_name}-google-client-id" }
}

resource "aws_ssm_parameter" "google_map_api_key" {
  name  = "${local.ssm_prefix}/GOOGLE_MAP_API_KEY"
  type  = "SecureString"
  value = var.google_map_api_key

  tags = { Name = "${var.app_name}-google-map-api-key" }
}

resource "aws_ssm_parameter" "paizaio_api_key" {
  name  = "${local.ssm_prefix}/PAIZAIO_API_KEY"
  type  = "SecureString"
  value = var.paizaio_api_key

  tags = { Name = "${var.app_name}-paizaio-api-key" }
}

resource "aws_ssm_parameter" "openai_api_key" {
  name  = "${local.ssm_prefix}/OPENAI_API_KEY"
  type  = "SecureString"
  value = var.openai_api_key

  tags = { Name = "${var.app_name}-openai-api-key" }
}

resource "aws_ssm_parameter" "frontend_url" {
  name  = "${local.ssm_prefix}/FRONTEND_URL"
  type  = "String"
  value = var.frontend_url

  tags = { Name = "${var.app_name}-frontend-url" }
}
