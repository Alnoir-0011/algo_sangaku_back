# DB サブネットグループ (プライベートサブネット)
resource "aws_db_subnet_group" "main" {
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_c.id]

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

# RDS インスタンス
resource "aws_db_instance" "main" {
  identifier        = "${var.app_name}-db"
  instance_class    = var.db_instance_class
  engine            = "postgres"

  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  apply_immediately   = true
  publicly_accessible = false
  multi_az            = false
  storage_encrypted   = true

  deletion_protection = true

  # 削除時に最終スナップショットを自動取得
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.app_name}-db-final-snapshot"

  tags = {
    Name = "${var.app_name}-db"
  }
}
