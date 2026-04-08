#!/bin/sh
set -e

# queue コンテナ専用 entrypoint
# db:prepare は web コンテナが担当するため、ここではスキップする
# (ECS の dependsOn で web が HEALTHY になるまで待機してから起動)

exec "$@"
