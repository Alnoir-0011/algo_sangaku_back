output "ecr_rails_url" {
  description = "Rails コンテナの ECR リポジトリ URL"
  value       = aws_ecr_repository.rails.repository_url
}

output "ecr_nginx_url" {
  description = "nginx コンテナの ECR リポジトリ URL"
  value       = aws_ecr_repository.nginx.repository_url
}

output "ec2_elastic_ip" {
  description = "EC2 の Elastic IP アドレス"
  value       = aws_eip.main.public_ip
}

output "cloudfront_domain_name" {
  description = "CloudFront ディストリビューションのドメイン名"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "rds_endpoint" {
  description = "RDS エンドポイント"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "ECS クラスター名"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS サービス名"
  value       = aws_ecs_service.main.name
}

output "github_oidc_role_arn" {
  description = "GitHub Actions OIDC 用 IAM ロールの ARN"
  value       = aws_iam_role.github_actions_oidc.arn
}

# Rails 側はこの名前を config.x の定数で持つ (#322)。環境変数では渡せない事情は
# terraform/lambda.tf の locals を参照。
output "code_runner_function_name" {
  description = "コード実行 Lambda の関数名"
  value       = aws_lambda_function.code_runner.function_name
}

output "code_runner_function_arn" {
  description = "コード実行 Lambda の ARN"
  value       = aws_lambda_function.code_runner.arn
}
