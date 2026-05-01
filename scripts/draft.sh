#!/bin/bash
# 创建本地发布草稿，不触发小红书发布。
# 用法: ./draft.sh '{"title":"标题","content":"正文","images":["/abs/a.png"],"tags":["标签"]}'

set -euo pipefail

PAYLOAD="${1:-}"
DRAFT_DIR="${XHS_DRAFT_DIR:-$HOME/.xiaohongshu/drafts}"

if ! command -v jq >/dev/null 2>&1; then
    echo "错误: 需要安装 jq"
    exit 1
fi

if [ -z "$PAYLOAD" ]; then
    echo "用法: $0 '<publish_content JSON payload>'"
    exit 1
fi

if ! echo "$PAYLOAD" | jq empty 2>/dev/null; then
    echo "错误: 参数不是合法 JSON"
    exit 1
fi

TITLE=$(echo "$PAYLOAD" | jq -r '.title // empty')
CONTENT=$(echo "$PAYLOAD" | jq -r '.content // empty')
IMAGE_COUNT=$(echo "$PAYLOAD" | jq '.images // [] | length')
VIDEO=$(echo "$PAYLOAD" | jq -r '.video // empty')

if [ -z "$TITLE" ]; then
    echo "错误: 缺少 title"
    exit 1
fi
if [ -z "$CONTENT" ]; then
    echo "错误: 缺少 content"
    exit 1
fi
if [ "$IMAGE_COUNT" -eq 0 ] && [ -z "$VIDEO" ]; then
    echo "错误: 图文草稿至少需要 images，视频草稿需要 video"
    exit 1
fi

mkdir -p "$DRAFT_DIR"
chmod 700 "$DRAFT_DIR" 2>/dev/null || true

TS=$(date +%Y%m%dT%H%M%S)
SLUG=$(echo "$TITLE" | tr -cd '[:alnum:]_-' | cut -c1-24)
[ -z "$SLUG" ] && SLUG="xhs"
OUT="$DRAFT_DIR/${TS}-${SLUG}.json"

echo "$PAYLOAD" | jq '. + {"_draft_created_at": now | todateiso8601}' > "$OUT"
chmod 600 "$OUT"

echo "✓ 已创建本地草稿: $OUT"
echo ""
echo "标题: $TITLE"
echo "正文字符数: $(printf '%s' "$CONTENT" | wc -m | tr -d ' ')"
echo "图片数: $IMAGE_COUNT"
[ -n "$VIDEO" ] && echo "视频: $VIDEO"
echo ""
echo "确认无误后发布："
echo "  ./publish-draft.sh '$OUT' --yes"
