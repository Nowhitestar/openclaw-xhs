#!/bin/bash
# 调用底层 MCP 保存到小红书平台草稿（不会点击发布）。
# 用法: ./save-platform-draft.sh latest
#      ./save-platform-draft.sh ~/.xiaohongshu/drafts/xxx.json

set -euo pipefail

DRAFT_REF="${1:-latest}"
DRAFT_DIR="${XHS_DRAFT_DIR:-$HOME/.xiaohongshu/drafts}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v jq >/dev/null 2>&1; then
    echo "错误: 需要安装 jq"
    exit 1
fi

if [ "$DRAFT_REF" = "latest" ]; then
    DRAFT_FILE=$(ls -t "$DRAFT_DIR"/*.json 2>/dev/null | head -1 || true)
else
    DRAFT_FILE="$DRAFT_REF"
fi

if [ -z "${DRAFT_FILE:-}" ] || [ ! -f "$DRAFT_FILE" ]; then
    echo "错误: 找不到草稿: $DRAFT_REF"
    exit 1
fi

PAYLOAD=$(jq 'del(._draft_created_at, .schedule_at)' "$DRAFT_FILE")
"$SCRIPT_DIR/mcp-call.sh" save_draft_content "$PAYLOAD"
