#!/bin/sh
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /algo_sangaku_back/tmp/pids/server.pid
mkdir -p /algo_sangaku_back/tmp/sockets /algo_sangaku_back/tmp/pids

bundle exec rails db:prepare
# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
