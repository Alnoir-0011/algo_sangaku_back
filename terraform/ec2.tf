# ECS-optimized AMI を SSM Parameter Store から取得
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
}

resource "aws_instance" "main" {
  ami                    = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ecs_instance.name
  key_name               = var.ec2_key_name != "" ? var.ec2_key_name : null

  # ECS クラスターへの登録
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    EOF
  )

  # AMI の更新による意図しない EC2 再作成を防ぐ。
  # セキュリティパッチ等で AMI を更新する場合は、
  # `terraform taint aws_instance.main` の後に `terraform apply` を実行すること。
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "${var.app_name}-ec2"
  }
}

# Elastic IP
resource "aws_eip" "main" {
  domain   = "vpc"
  instance = aws_instance.main.id

  tags = {
    Name = "${var.app_name}-eip"
  }
}
