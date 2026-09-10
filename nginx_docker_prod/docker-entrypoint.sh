#!/bin/sh
set -e

# 未設定・空文字のまま envsubst すると if ($http_x_cloudfront_secret != "") がフェイルオープンし
# CloudFront を経由しない直接アクセスの遮断が無効化されるため、起動時に必須チェックする
: "${CLOUDFRONT_SECRET:?CLOUDFRONT_SECRET is required}"

# $CLOUDFRONT_SECRET のみを nginx.conf.template に置換する
# nginx 固有の $変数 ($remote_addr, $uri 等) は envsubst の対象リストに含まれないため残る
envsubst '$CLOUDFRONT_SECRET' \
  < /etc/nginx/conf.d/app_name.conf.template \
  > /etc/nginx/conf.d/app_name.conf

exec nginx -g 'daemon off;' -c /etc/nginx/nginx.conf
