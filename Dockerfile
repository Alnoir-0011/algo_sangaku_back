FROM ruby:3.3.6-alpine AS builder

RUN apk update && \
  apk add --no-cache \
  build-base \
  postgresql-dev

RUN gem install bundler
COPY Gemfile Gemfile.lock ./
ARG RAILS_ENV
RUN RAILS_ENV=${RAILS_ENV} bundle install

FROM ruby:3.3.6-alpine AS app

RUN apk update && \
  apk add --no-cache \
  tzdata \
  nodejs \
  postgresql-client \
  vim

WORKDIR /algo_sangaku_back

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY . /algo_sangaku_back

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ENTRYPOINT を使うことで CMD に渡したコマンドが entrypoint 経由で実行される
ENTRYPOINT ["entrypoint.sh"]

# 最終的に Puma を起動
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
