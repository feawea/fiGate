#!/bin/zsh
set -euo pipefail

LOG_DIR="$HOME/Library/Application Support/fiGate/logs"
mkdir -p "$LOG_DIR"

tail -f "$LOG_DIR/gateway.log" "$LOG_DIR/message.log" "$LOG_DIR/error.log"
