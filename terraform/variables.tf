variable "aws_region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_account_id" {
  description = "AWS アカウント ID"
  type        = string
}

variable "domain_name" {
  description = "サービスのドメイン名 (例: example.com)"
  type        = string
}

variable "app_name" {
  description = "アプリケーション名 (リソース名のプレフィックスに使用)"
  type        = string
  default     = "algo-sangaku"
}

# --- VPC ---
variable "vpc_cidr" {
  description = "VPC の CIDR ブロック"
  type        = string
  default     = "10.0.0.0/16"
}

# --- RDS ---

# db.t4g は PostgreSQL 12.0 以上が必要。スナップショット元のエンジンバージョンを事前に確認すること。
variable "db_instance_class" {
  description = "RDS インスタンスクラス"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "データベース名"
  type        = string
  default     = "myapp_production"
}

variable "db_username" {
  description = "データベースユーザー名"
  type        = string
  default     = "postgres"
}

# --- EC2 / ECS ---
variable "ec2_instance_type" {
  description = "EC2 インスタンスタイプ"
  type        = string
  default     = "t4g.micro"
}

variable "ec2_key_name" {
  description = "EC2 キーペア名 (SSH 接続用。不要な場合は空文字)"
  type        = string
  default     = ""
}

# --- SSM Parameter Store (SecureString) ---
variable "rails_master_key" {
  description = "Rails の MASTER_KEY (config/master.key の値)"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "RDS データベースパスワード (既存 RDS のパスワードと一致させる)"
  type        = string
  sensitive   = true
}

variable "google_client_id" {
  description = "Google OAuth クライアント ID"
  type        = string
  sensitive   = true
}

variable "google_map_api_key" {
  description = "Google Maps API キー"
  type        = string
  sensitive   = true
}

variable "paizaio_api_key" {
  description = "PaizaIO API キー"
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API キー"
  type        = string
  sensitive   = true
}

variable "frontend_url" {
  description = "フロントエンドの URL (CORS 許可用)"
  type        = string
}

# --- CloudFront カスタムヘッダー ---
variable "cloudfront_secret_header_value" {
  description = "CloudFront → EC2 間のカスタムヘッダー値。ランダムな文字列を生成して設定すること (例: openssl rand -hex 32)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cloudfront_secret_header_value) >= 32
    error_message = "cloudfront_secret_header_value は 32 文字以上のランダムな文字列を使用してください。"
  }
}

# --- GitHub Actions OIDC ---
variable "github_repo" {
  description = "GitHub リポジトリ (例: Alnoir-0011/algo_sangaku_back)"
  type        = string
  default     = "Alnoir-0011/algo_sangaku_back"
}
