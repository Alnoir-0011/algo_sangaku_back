terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 現在はローカル state 管理。チーム開発や本番運用では S3 + DynamoDB へ移行を推奨。
  # 移行する場合は以下のコメントアウトを解除し、S3 バケット/DynamoDB テーブルを事前作成する。
  #
  # backend "s3" {
  #   bucket         = "algo-sangaku-terraform-state"
  #   key            = "prod/terraform.tfstate"
  #   region         = "ap-northeast-1"
  #   dynamodb_table = "algo-sangaku-terraform-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

# us-east-1 エイリアス (ACM 証明書は CloudFront 用に us-east-1 が必須)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
