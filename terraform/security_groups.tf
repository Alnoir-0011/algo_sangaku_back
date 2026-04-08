# CloudFront マネージドプレフィックスリストを取得
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# --- EC2 セキュリティグループ ---
# CloudFront からの HTTP のみ許可 (SG レベルで IP 制限)
resource "aws_security_group" "ec2" {
  name        = "${var.app_name}-ec2-sg"
  description = "Allow HTTP from CloudFront only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from CloudFront"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-ec2-sg"
  }
}

# --- RDS セキュリティグループ ---
# EC2 SG からの PostgreSQL のみ許可
resource "aws_security_group" "rds" {
  name        = "${var.app_name}-rds-sg"
  description = "Allow PostgreSQL from EC2 SG only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-rds-sg"
  }
}
