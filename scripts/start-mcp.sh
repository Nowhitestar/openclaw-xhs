#!/bin/bash
# 启动小红书 MCP 服务（安全默认：仅本机监听，cookies 留在 ~/.xiaohongshu）

set -e

XHS_MCP="${XHS_MCP_BIN:-$HOME/.local/bin/xiaohongshu-mcp}"
STATE_DIR="${XHS_STATE_DIR:-$HOME/.xiaohongshu}"
PID_FILE="$STATE_DIR/mcp.pid"
LOG_FILE="$STATE_DIR/mcp.log"
XVFB_PID_FILE="$STATE_DIR/xvfb.pid"
XVFB_DISPLAY_FILE="$STATE_DIR/xvfb.display"

# Cookies 路径（可通过环境变量覆盖）
# 安全默认：不再使用 /tmp/cookies.json；登录态保存在 ~/.xiaohongshu/cookies.json
# XHS_COOKIES_SRC 可用于从显式指定路径导入 cookies（例如迁移远程服务器登录态）。
COOKIES_DST="${COOKIES_PATH:-$STATE_DIR/cookies.json}"
export COOKIES_PATH="$COOKIES_DST"

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR" 2>/dev/null || true

if [ ! -x "$XHS_MCP" ]; then
    echo "错误: xiaohongshu-mcp 不存在或不可执行: $XHS_MCP"
    echo "请先运行 ./install-check.sh 查看安装指引。"
    exit 1
fi

# 检测是否有显示器（桌面环境）
has_display() {
    [ -n "${DISPLAY:-}" ] && command -v xdpyinfo >/dev/null 2>&1 && xdpyinfo >/dev/null 2>&1
}

# 在无桌面环境下自动启动 Xvfb
ensure_display() {
    if has_display; then
        return 0
    fi

    if [ -f "$XVFB_PID_FILE" ]; then
        local pid
        pid=$(cat "$XVFB_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            export DISPLAY=$(cat "$XVFB_DISPLAY_FILE" 2>/dev/null || echo ":99")
            echo "复用已有 Xvfb (PID: $pid, DISPLAY=$DISPLAY)"
            return 0
        fi
    fi

    if ! command -v Xvfb >/dev/null 2>&1; then
        echo "⚠ 未检测到桌面环境，且未安装 Xvfb。"
        echo "  Debian/Ubuntu: sudo apt-get install -y xvfb"
        echo "  macOS/桌面环境通常不需要 Xvfb。"
        exit 1
    fi

    echo "未检测到桌面环境，自动启动 Xvfb 虚拟显示..."

    local display_num=""
    local d
    for d in $(seq 99 109); do
        if [ ! -e "/tmp/.X${d}-lock" ]; then
            display_num=$d
            break
        fi
        local lock_pid
        lock_pid=$(cat "/tmp/.X${d}-lock" 2>/dev/null | tr -d ' ')
        if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
            rm -f "/tmp/.X${d}-lock" "/tmp/.X11-unix/X${d}" 2>/dev/null
            if [ ! -e "/tmp/.X${d}-lock" ]; then
                display_num=$d
                break
            fi
        fi
    done

    if [ -z "$display_num" ]; then
        echo "✗ 无法找到可用的 display 号（:99-:109 均被占用）"
        exit 1
    fi

    Xvfb ":${display_num}" -screen 0 1024x768x24 -ac >/dev/null 2>&1 &
    echo $! > "$XVFB_PID_FILE"
    echo ":${display_num}" > "$XVFB_DISPLAY_FILE"
    export DISPLAY=":${display_num}"
    sleep 1

    if kill -0 "$(cat "$XVFB_PID_FILE")" 2>/dev/null; then
        echo "✓ Xvfb 已启动 (DISPLAY=:${display_num})"
    else
        echo "✗ Xvfb 启动失败"
        exit 1
    fi
}

sync_cookies() {
    local src=""

    if [ -n "${XHS_COOKIES_SRC:-}" ] && [ -f "$XHS_COOKIES_SRC" ]; then
        src="$XHS_COOKIES_SRC"
    elif [ -f "$COOKIES_DST" ]; then
        chmod 600 "$COOKIES_DST" 2>/dev/null || true
        return 0
    fi

    if [ -n "$src" ]; then
        install -m 600 "$src" "$COOKIES_DST"
        echo "已导入 cookies: $src -> $COOKIES_DST"
    fi
}

sync_cookies
ensure_display

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "MCP 服务已在运行 (PID: $PID)"
        echo "如需重启，请先运行 stop-mcp.sh"
        exit 0
    fi
fi

HEADLESS="true"
HOST="${XHS_MCP_HOST:-127.0.0.1}"
PORT="${XHS_MCP_PORT:-18060}"
for arg in "$@"; do
    case $arg in
        --headless=false)
            HEADLESS="false"
            ;;
        --host=*)
            HOST="${arg#*=}"
            ;;
        --port=*)
            PORT="${arg#*=}"
            ;;
    esac
done

if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
    echo "错误: 无效端口号: $PORT"
    exit 1
fi

if [[ ! "$HOST" =~ ^[A-Za-z0-9_.:-]+$ ]]; then
    echo "错误: 无效监听地址: $HOST"
    exit 1
fi

ADDR="${HOST}:${PORT}"
ENDPOINT="http://${HOST}:${PORT}/mcp"

# 启动服务
echo "启动小红书 MCP 服务..."
echo "  监听: $ADDR"
echo "  cookies: $COOKIES_DST"
if [ "$HEADLESS" = "false" ]; then
    nohup "$XHS_MCP" -port "$ADDR" -headless=false > "$LOG_FILE" 2>&1 &
else
    nohup "$XHS_MCP" -port "$ADDR" > "$LOG_FILE" 2>&1 &
fi

echo $! > "$PID_FILE"
sleep 2

if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    chmod 600 "$COOKIES_DST" 2>/dev/null || true
    echo "✓ MCP 服务已启动 (PID: $(cat "$PID_FILE"))"
    echo "  端点: $ENDPOINT"
    echo "  日志: $LOG_FILE"
else
    echo "✗ 启动失败，查看日志: $LOG_FILE"
    cat "$LOG_FILE"
    exit 1
fi
