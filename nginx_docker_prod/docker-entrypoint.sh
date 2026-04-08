#!/bin/sh
set -e

# $CLOUDFRONT_SECRET のみを nginx.conf.template に置換する
# nginx 固有の $変数 ($remote_addr, $uri 等) は envsubst の対象リストに含まれないため残る
envsubst '$CLOUDFRONT_SECRET' \
  < /etc/nginx/conf.d/app_name.conf.template \
  > /etc/nginx/conf.d/app_name.conf

exec nginx -g 'daemon off;' -c /etc/nginx/nginx.conf
