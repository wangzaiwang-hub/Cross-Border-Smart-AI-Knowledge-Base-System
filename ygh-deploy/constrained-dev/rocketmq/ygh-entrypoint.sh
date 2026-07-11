#!/bin/sh
set -eu

mode="${1:?mode is required}"
shift

case "$mode" in
  namesrv)
    target="${ROCKETMQ_HOME}/bin/mqnamesrv"
    ;;
  broker)
    target="${ROCKETMQ_HOME}/bin/mqbroker"
    ;;
  *)
    echo "Unsupported RocketMQ mode: $mode" >&2
    exit 2
    ;;
esac

# RocketMQ 官方启动脚本会再派生 shell 和 Java 进程。为其创建独立进程组，
# 确保 Docker 的 TERM 信号能传给整个进程树并触发 Broker 落盘退出。
setsid sh "$target" "$@" &
child_pid=$!

terminate() {
  kill -TERM "-$child_pid" 2>/dev/null || true
  wait "$child_pid" 2>/dev/null || true
  exit 0
}

trap terminate TERM INT
wait "$child_pid"
