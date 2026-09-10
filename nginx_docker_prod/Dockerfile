FROM nginx:1.27-alpine

# gettext: envsubst コマンドを提供 (nginx.conf への環境変数埋め込みに使用)
# curl は nginx:1.27-alpine に同梱済みのため追加不要 (ECS ヘルスチェックで使用)
RUN apk add --no-cache gettext

RUN rm -f /etc/nginx/conf.d/*

COPY nginx.conf.template /etc/nginx/conf.d/app_name.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

