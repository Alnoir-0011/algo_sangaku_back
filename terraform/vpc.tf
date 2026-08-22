resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# --- パブリックサブネット (EC2 配置) ---
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0) # 10.0.0.0/24
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-a"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1) # 10.0.1.0/24
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-c"
  }
}

# --- プライベートサブネット (RDS 配置) ---
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10) # 10.0.10.0/24
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.app_name}-private-a"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 11) # 10.0.11.0/24
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "${var.app_name}-private-c"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-igw"
  }
}

# --- ルートテーブル (パブリック) ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.app_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

# --- サンドボックスサブネット (Lambda code_runner 配置) ---
#
# 既存の private_a / private_c は流用しない。理由は 2 つある。
#   1. aws_db_subnet_group.main により RDS が同居しており、到達性が生まれる
#   2. private_a / private_c にはルートテーブルの関連付けが無い。これは「ルートが無い」
#      ではなく「VPC のメインルートテーブルに暗黙的に従っている」という意味であり、
#      将来メイン RT に 0.0.0.0/0 が足されるとサンドボックスが黙って外に出られるようになる
#
# ここでは専用サブネットを新設し、ルートを 1 つも持たない専用 RT を明示的に関連付けて
# 暗黙追従を断ち切る。
resource "aws_subnet" "sandbox_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20) # 10.0.20.0/24
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.app_name}-sandbox-a"
  }
}

resource "aws_subnet" "sandbox_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 21) # 10.0.21.0/24
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "${var.app_name}-sandbox-c"
  }
}

# --- ルートテーブル (サンドボックス) ---
# route ブロックを 1 つも書かないのは意図的である。VPC 内のローカルルート以外の経路を
# 持たせないことで、インターネット・NAT・VPC エンドポイントのいずれにも到達させない。
# ルートを足すと隔離が壊れるので、追加する前に必ず lambda/code_runner/README.md の
# 脅威モデルを読むこと。
resource "aws_route_table" "sandbox" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-sandbox-rt"
  }
}

# 関連付けを明示的に張ることが要点。省略するとメイン RT に暗黙追従してしまう。
resource "aws_route_table_association" "sandbox_a" {
  subnet_id      = aws_subnet.sandbox_a.id
  route_table_id = aws_route_table.sandbox.id
}

resource "aws_route_table_association" "sandbox_c" {
  subnet_id      = aws_subnet.sandbox_c.id
  route_table_id = aws_route_table.sandbox.id
}
