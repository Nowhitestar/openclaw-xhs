#!/bin/bash
# 从本地草稿发布到小红书。默认只预览；必须传 --yes 才会真正调用 MCP 发布。
# 用法: ./publish-draft.sh latest
#      ./publish-draft.sh ~/.xiaohongshu/drafts/xxx.json --yes

set -euo pipefail

DRAFT_REF="${1:-latest}"
CONFIRM="${2:-}"
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

TITLE=$(jq -r '.title // empty' "$DRAFT_FILE")
CONTENT=$(jq -r '.content // empty' "$DRAFT_FILE")
IMAGE_COUNT=$(jq '.images // [] | length' "$DRAFT_FILE")
VIDEO=$(jq -r '.video // empty' "$DRAFT_FILE")
TAGS=$(jq -r '.tags // [] | join(", ")' "$DRAFT_FILE")

cat <<EOF
【小红书本地草稿预览】
文件: $DRAFT_FILE
标题: $TITLE
正文字符数: $(printf '%s' "$CONTENT" | wc -m | tr -d ' ')
图片数: $IMAGE_COUNT
视频: ${VIDEO:-无}
标签: ${TAGS:-无}

正文：
$CONTENT
EOF

if [ "$CONFIRM" != "--yes" ]; then
    echo ""
    echo "未发布。确认后执行："
    echo "  $0 '$DRAFT_FILE' --yes"
    exit 0
fi

if [ -n "$VIDEO" ] && [ "$VIDEO" != "null" ]; then
    TOOL="publish_with_video"
else
    TOOL="publish_content"
fi

# 去掉本地草稿元数据，只保留 MCP 参数
PAYLOAD=$(jq 'del(._draft_created_at)' "$DRAFT_FILE")
"$SCRIPT_DIR/mcp-call.sh" "$TOOL" "$PAYLOAD"
