#!/usr/bin/env bash
# check-cline-free-models.sh
#
# 查询 Cline 当前「限时免费」模型池（cline-free/*），并判断里面有没有 DeepSeek。
#
# 背景：Cline 的免费模型池是服务端下发的、按推广周期轮换的列表，客户端（VS Code 插件 /
# CLI）只是把它渲染成模型选择器里的 "Free" 标签页。这个端点无需鉴权即可读取，
# 因此可以用它来判断「今天能不能白嫖到 DeepSeek」。
#
# 用法:
#   ./scripts/check-cline-free-models.sh            # 人类可读输出
#   ./scripts/check-cline-free-models.sh --json     # 原始 JSON
#   ./scripts/check-cline-free-models.sh --quiet    # 只输出结论, 供脚本/CI 判断
#   退出码: 0 = 免费池里有 DeepSeek, 1 = 没有, 2 = 查询失败
#
# 依赖: curl + jq (或 curl + python3)

set -euo pipefail

URL="${CLINE_RECOMMENDED_MODELS_URL:-https://api.cline.bot/api/v1/ai/cline/recommended-models}"

MODE="human"
case "${1:-}" in
	--json) MODE="json" ;;
	--quiet) MODE="quiet" ;;
	--help | -h)
		sed -n '2,20p' "$0"
		exit 0
		;;
esac

raw="$(curl -fsS --max-time 20 "$URL")" || {
	echo "ERROR: 无法读取 $URL" >&2
	exit 2
}

if [ "$MODE" = "json" ]; then
	echo "$raw"
	exit 0
fi

# 优先用 jq, 否则退回 python3
if command -v jq >/dev/null 2>&1; then
	READER=jq
elif command -v python3 >/dev/null 2>&1; then
	READER=python3
else
	echo "ERROR: 需要 jq 或 python3" >&2
	exit 2
fi

dump() { # dump <bucket>
	if [ "$READER" = "jq" ]; then
		printf '%s' "$raw" | jq -r --arg b "$1" '.[$b][]? | "  \(.id)\t\(.name)"'
	else
		printf '%s' "$raw" | python3 -c '
import json,sys
b=sys.argv[1]
for m in json.load(sys.stdin).get(b) or []:
    print("  %s\t%s" % (m.get("id"), m.get("name")))
' "$1"
	fi
}

free_ids="$([ "$READER" = "jq" ] && printf '%s' "$raw" | jq -r '.free[]?.id' || printf '%s' "$raw" | python3 -c 'import json,sys;print("\n".join(m.get("id","") for m in json.load(sys.stdin).get("free") or []))')"
deepseek_free="$(printf '%s\n' "$free_ids" | grep -i 'deepseek' || true)"

if [ "$MODE" = "quiet" ]; then
	if [ -n "$deepseek_free" ]; then
		echo "$deepseek_free"
		exit 0
	fi
	exit 1
fi

echo "Cline 推荐/免费模型池  ($URL)"
echo "查询时间: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo
echo "== free (cline-free/*, 计费为 \$0, 需要 Cline 账号登录) =="
dump free
echo
echo "== clinePass (需订阅, \$9.99/月) =="
dump clinePass
echo
echo "== clineCloud (按需) =="
dump clineCloud
echo

if [ -n "$deepseek_free" ]; then
	echo "结论: 免费池里有 DeepSeek:"
	printf '  %s\n' $deepseek_free
	echo "-> 在 VS Code 里: Cline 设置 -> API Provider = Cline -> 登录 -> 模型选择器 Free 标签里选它。"
	exit 0
fi

echo "结论: 当前免费池里没有 DeepSeek。"
echo "-> DeepSeek 只能通过以下方式使用:"
echo "   1) 自带 DeepSeek 官方 API key (按量付费, 最稳)"
echo "   2) ClinePass 订阅 (cline-pass/deepseek-v4.1-flash, cline-pass/deepseek-v4-pro)"
echo "   3) 其它聚合/本地部署 (OpenRouter、Ollama 等)"
exit 1
