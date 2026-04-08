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
