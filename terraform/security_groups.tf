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

# --- Lambda code_runner セキュリティグループ ---
#
# ★ ingress ブロックも egress ブロックも書いていないのは意図的である（書き忘れではない）。
#
# Terraform の aws_security_group は egress を省略すると AWS デフォルトの全許可ルールを
# 「削除」する。これがまさに欲しい挙動で、アウトバウンドが完全に遮断される。
# 結果としてインターネット・RDS・AWS API のいずれにも到達できなくなる。
#
# ここにルールを 1 つでも足すと、第三者が投稿した任意コードから外部へ出られるようになる。
# code_runner は信頼できないコードを実行する前提で作られており、ハンドラ側では
# この経路を塞げない（/usr/bin/curl も存在する）。追加する前に必ず
# lambda/code_runner/README.md の「防げないもの」を読むこと。
#
# ループバック (127.0.0.1:9001 の Lambda Runtime API) だけは SG の対象外なので通る。
# これは残存リスクとして受容済みで、「期待値を絶対に Lambda に渡さない」ことで無害化している。
resource "aws_security_group" "code_runner" {
  name        = "${var.app_name}-code-runner-sg"
  description = "No ingress and no egress by design (untrusted code sandbox)"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-code-runner-sg"
  }
}
