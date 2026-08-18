# デプロイ運用ガイド

## アーキテクチャ概要

```
Route53 (A alias)
  └─ CloudFront (HTTPS / ACM us-east-1)
       └─ EC2 t4g.micro / AL2023 arm64 (Elastic IP)
            └─ ECS on EC2 (bridge mode)
                 ├─ nginx コンテナ (port 80)
                 ├─ web コンテナ (Rails/Puma, unix socket)
                 └─ queue コンテナ (Solid Queue)
                      └─ RDS PostgreSQL db.t4g.micro (private subnet)
```

- **Terraform state**: ローカル管理（`back/terraform/terraform.tfstate`）
- **ECS タスク定義**: `lifecycle { ignore_changes = [container_definitions] }` のため、Terraform は初回作成のみ管理。以降のイメージ更新・secrets 追加は手動または GitHub Actions が担う。

---

## 初回インフラ構築

### 前提確認

```bash
terraform version        # 1.9.0 以上
aws sts get-caller-identity  # AWS 認証確認
gh auth status           # GitHub CLI 認証確認（Phase 4 で使用）
```

### `terraform.tfvars` を準備

```bash
cd back/terraform
cp terraform.tfvars.example terraform.tfvars
# 各変数を埋める（下表参照）
```

| 変数 | 取得方法 |
|---|---|
| `aws_account_id` | `aws sts get-caller-identity --query Account --output text` |
| `domain_name` | サービスのドメイン名（例: algosangaku-api.com） |
| `frontend_url` | フロントエンドの URL |
| `cloudfront_secret_header_value` | `openssl rand -hex 32` |
| `client_secret` | `openssl rand -hex 32` |
| `rails_master_key` | `back/config/master.key` の内容 |
| `db_password` | 任意のパスワード（新規 RDS に設定される） |
| `google_client_id` / `google_map_api_key` | Google Cloud Console |
| `paizaio_api_key` | PaizaIO ダッシュボード |
| `openai_api_key` | OpenAI ダッシュボード |
| `github_repo` | `Alnoir-0011/algo_sangaku_back`（デフォルト値あり） |

### GitHub OIDC プロバイダーの確認

```bash
aws iam list-open-id-connect-providers
# 存在しない場合は AWS コンソールまたは別途 terraform で作成する
```

### Terraform apply

```bash
cd back/terraform
terraform init
terraform validate
terraform plan
terraform apply
```

> ACM 証明書の DNS 検証に最大 30 分かかる。`terraform apply` が待機中になるのはそのまま待つ。

---

## アプリデプロイ（ローカルから手動実行）

main ブランチへの PR マージ時は `autodeploy.yml` が自動デプロイする。ローカルから手動で行う場合:

```bash
cd back/terraform

# 1. ECR ログイン
REGISTRY=$(terraform output -raw ecr_rails_url | cut -d/ -f1)
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin "$REGISTRY"

# 2. イメージのビルド & push（EC2 が arm64 のため linux/arm64 必須）
SHORT_SHA=$(git -C .. rev-parse --short=7 HEAD)
ECR_RAILS=$(terraform output -raw ecr_rails_url)
ECR_NGINX=$(terraform output -raw ecr_nginx_url)

docker build --platform linux/arm64 --build-arg RAILS_ENV=production \
  -t "$ECR_RAILS:latest" -t "$ECR_RAILS:$SHORT_SHA" ../
docker push "$ECR_RAILS:latest" && docker push "$ECR_RAILS:$SHORT_SHA"

docker build --platform linux/arm64 -f ../nginx_docker_prod/Dockerfile \
  -t "$ECR_NGINX:latest" -t "$ECR_NGINX:$SHORT_SHA" ../nginx_docker_prod/
docker push "$ECR_NGINX:latest" && docker push "$ECR_NGINX:$SHORT_SHA"

# 3. タスク定義の新リビジョンを登録 & ECS サービス更新
TASK_FAMILY=algo-sangaku
TASK_DEF=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --query taskDefinition --output json)
NEW_DEF=$(echo "$TASK_DEF" | jq \
  --arg rails "$ECR_RAILS:$SHORT_SHA" --arg nginx "$ECR_NGINX:$SHORT_SHA" \
  '(.containerDefinitions[] | select(.name=="web")  | .image) |= $rails |
   (.containerDefinitions[] | select(.name=="queue") | .image) |= $rails |
   (.containerDefinitions[] | select(.name=="nginx") | .image) |= $nginx |
   del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy)')
NEW_ARN=$(aws ecs register-task-definition --cli-input-json "$NEW_DEF" \
  --query 'taskDefinition.taskDefinitionArn' --output text)
aws ecs update-service \
  --cluster "$(terraform output -raw ecs_cluster_name)" \
  --service "$(terraform output -raw ecs_service_name)" \
  --task-definition "$NEW_ARN" --force-new-deployment
```

### GitHub Actions Secrets の登録（初回のみ）

```bash
cd back/terraform
gh secret set ECR_RAILS_URL     --body "$(terraform output -raw ecr_rails_url)"
gh secret set ECR_NGINX_URL     --body "$(terraform output -raw ecr_nginx_url)"
gh secret set ECS_CLUSTER_NAME  --body "$(terraform output -raw ecs_cluster_name)"
gh secret set ECS_SERVICE_NAME  --body "$(terraform output -raw ecs_service_name)"
gh secret set AWS_OIDC_ROLE_ARN --body "$(terraform output -raw github_oidc_role_arn)"
gh secret set ECS_TASK_FAMILY   --body "algo-sangaku"
```

---

## シークレット（環境変数）を追加するときのフロー

`lifecycle { ignore_changes = [container_definitions] }` のため、`terraform apply` だけでは ECS タスク定義に反映されない。以下の 3 ステップが必要。

### ステップ 1: Terraform 側に追加

```hcl
# variables.tf
variable "new_secret" {
  description = "..."
  type        = string
  sensitive   = true
}

# ssm.tf
resource "aws_ssm_parameter" "new_secret" {
  name  = "${local.ssm_prefix}/NEW_SECRET"
  type  = "SecureString"
  value = var.new_secret
  tags  = { Name = "${var.app_name}-new-secret" }
}

# ecs.tf の該当コンテナの secrets にも追記しておく（ドキュメント兼ねて記載する）
{ name = "NEW_SECRET", valueFrom = aws_ssm_parameter.new_secret.arn },
```

### ステップ 2: `terraform.tfvars` に値を追加して apply

```bash
cd back/terraform
# terraform.tfvars に new_secret = "値" を追記してから:
terraform apply   # SSM パラメータが作成される
```

### ステップ 3: ECS タスク定義に secrets を同期（手動・必須）

```bash
cd back/terraform
SHORT_SHA=$(git -C .. rev-parse --short=7 HEAD)
ECR_RAILS=$(terraform output -raw ecr_rails_url)
ECR_NGINX=$(terraform output -raw ecr_nginx_url)
TASK_FAMILY=algo-sangaku

NEW_SECRET_ARN=$(aws ssm get-parameter --name "/algo-sangaku/NEW_SECRET" \
  --query 'Parameter.ARN' --output text)

TASK_DEF=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --query taskDefinition --output json)
NEW_DEF=$(echo "$TASK_DEF" | jq \
  --arg rails "$ECR_RAILS:$SHORT_SHA" --arg nginx "$ECR_NGINX:$SHORT_SHA" \
  --arg arn "$NEW_SECRET_ARN" \
  '(.containerDefinitions[] | select(.name=="web")  | .image) |= $rails |
   (.containerDefinitions[] | select(.name=="queue") | .image) |= $rails |
   (.containerDefinitions[] | select(.name=="nginx") | .image) |= $nginx |
   (.containerDefinitions[] | select(.name=="web")  | .secrets) += [{"name":"NEW_SECRET","valueFrom":$arn}] |
   del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy)')
NEW_ARN=$(aws ecs register-task-definition --cli-input-json "$NEW_DEF" \
  --query 'taskDefinition.taskDefinitionArn' --output text)
aws ecs update-service \
  --cluster "$(terraform output -raw ecs_cluster_name)" \
  --service "$(terraform output -raw ecs_service_name)" \
  --task-definition "$NEW_ARN" --force-new-deployment
```

> この操作以降、GitHub Actions の通常デプロイでも新しい secret が引き継がれる（既存タスク定義をベースにするため）。

---

## トラブルシューティング

| 症状 | 確認コマンド | 対処 |
|---|---|---|
| ECS タスクが起動しない | `aws ecs describe-tasks --cluster algo-sangaku-cluster --tasks <TASK_ID>` | `stoppedReason` と `containers[].reason` を確認 |
| 環境変数が見つからない | `aws logs tail /ecs/algo-sangaku/web --since 5m` | secrets に対象の SSM パラメータが含まれているか確認。含まれていない場合は「シークレット追加フロー ステップ 3」を実施 |
| DB 接続エラー | `aws logs tail /ecs/algo-sangaku/web --since 5m` | RDS SG の 5432 inbound が EC2 SG からのみ許可されているか確認 |
| 503 が返る | `aws logs tail /ecs/algo-sangaku/nginx --since 5m` | web コンテナの HEALTHY 待ち or unix socket パス（`/tmp/puma`）を確認 |
| CloudFront で 403/502 | nginx ログを確認 | `X-CloudFront-Secret` ヘッダー値が SSM と一致しているか確認 |
| ACM 証明書が検証されない | `aws acm describe-certificate --certificate-arn <ARN> --region us-east-1` | Route53 に CNAME 検証レコードが作成されているか確認 |
| ECS タスクが一切スケジュールされない | `aws ecs describe-container-instances --cluster algo-sangaku-cluster --container-instances <ID> --query 'containerInstances[0].agentConnected'` | `false` ならエージェント障害。「EC2 ホストに入る」で `/var/log/ecs/ecs-agent.log` を確認する |

---

## EC2 インスタンスタイプを変更するとき

**ECS on EC2 では、稼働中インスタンスのタイプ変更はサポートされていない。**

`terraform.tfvars` の `ec2_instance_type` を変更して `terraform apply` すると、plan は `0 to add, 1 to change, 0 to destroy`（インプレース更新）を示し、EC2 も正常に起動する。**terraform のレイヤーでは何も問題が出ない。** しかし ECS エージェントの `RegisterContainerInstance` が 400 で拒否される。

```
ClientException: Container instance type changes are not supported.
Container instance <ID> was previously registered as t4g.micro.
```

エージェントは terminal exit（exit code 5）し、**タスクが一切スケジュールされなくなる**。`essential = false` の queue だけでなく web も起動しないため、**サービスが完全に停止する**。EC2 の再起動を繰り返しても復旧しない。

### 推奨手順: EC2 を作り直す

```bash
cd back/terraform
# terraform.tfvars の ec2_instance_type を変更してから
terraform taint aws_instance.main
terraform apply
```

新規インスタンスとして起動するため user_data が再実行され、新しいコンテナインスタンスとして登録される。EIP は terraform が再アタッチする。

### すでにタイプ変更して apply してしまった場合の復旧手順

```bash
# 1. 古い登録（変更前のタイプ）を破棄する
aws ecs deregister-container-instance --cluster algo-sangaku-cluster \
  --container-instance <CONTAINER_INSTANCE_ID> --force --region ap-northeast-1

# 2. エージェントの checkpoint を退避して再起動する（SSM 経由）
aws ssm send-command --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["mv /var/lib/ecs/data/agent.db /var/lib/ecs/data/agent.db.bak","systemctl restart ecs"]' \
  --region ap-northeast-1
```

**deregister だけでは復旧しない。** エージェントは `/var/lib/ecs/data/agent.db`（checkpoint）から古いコンテナインスタンス ARN を復元し続けるため、エラーが `type changes are not supported` から `is inactive` に変わるだけになる。checkpoint を外して初めて新規登録に切り替わる。

復旧後、登録内容が新しいインスタンスタイプになっていることを確認する。

```bash
aws ecs describe-container-instances --cluster algo-sangaku-cluster \
  --container-instances <NEW_ID> --region ap-northeast-1 \
  --query 'containerInstances[0].{memory:registeredResources[?name==`MEMORY`].integerValue,type:attributes[?name==`ecs.instance-type`].value}'
```

> **メモリ枠は自動では増えない。** インスタンスタイプを上げても、ECS の `registeredResources` は再登録するまで旧タイプの値のまま。t4g.micro=916MB / t4g.small=1846MB。

---

## EC2 ホストに入る

ECS エージェントが落ちるとタスクが起動せず、**ECS Exec も使えなくなる**（ECS Exec はタスクが動いている前提のため）。ホスト側の調査には SSM Session Manager を使う。EC2 インスタンスロールには `AmazonSSMManagedInstanceCore` をアタッチ済み（`terraform/iam.tf`）。

```bash
# 対話セッション
aws ssm start-session --target <INSTANCE_ID> --region ap-northeast-1

# 非対話でコマンド実行
CMD=$(aws ssm send-command --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl status ecs --no-pager","tail -30 /var/log/ecs/ecs-agent.log"]' \
  --region ap-northeast-1 --query 'Command.CommandId' --output text)

aws ssm get-command-invocation --command-id "$CMD" --instance-id <INSTANCE_ID> \
  --region ap-northeast-1 --query 'StandardOutputContent' --output text
```

調査時の主な確認先:

| 対象 | コマンド |
|---|---|
| ECS エージェントの状態 | `systemctl status ecs --no-pager` |
| エージェントのエラー | `tail -50 /var/log/ecs/ecs-agent.log` |
| クラスタ設定 | `cat /etc/ecs/ecs.config`（`ECS_CLUSTER` があるか） |
| Docker | `systemctl status docker --no-pager` / `docker ps -a` |
| ホストの実メモリ | `free -m` |

> SSH は使えない（`ec2_key_name` 未設定でキーペアなし）。SSM が唯一のホスト接続経路になる。
