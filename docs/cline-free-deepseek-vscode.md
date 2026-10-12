# 在 VS Code 里用上 Cline 的 cline-free（免费）DeepSeek 模型

> 调研时间：**2026-10-12** ｜ 基准版本：Cline VS Code 扩展 `saoudrizwan.claude-dev` **v4.1.23**（要求 VS Code ≥ 1.101.0）
> 源码基线：`cline/cline@03ffa9ec`（2026-10-12 main）｜ 免费池数据：实时抓取自 Cline 官方接口

---

## 0. TL;DR（先看这三条，能省你半小时）

1. **`cline-free/xxx` 不是"某个模型"，而是 Cline「限时免费推广」的模型 ID 前缀。**
   它的内容由服务端按推广周期轮换下发，客户端只是把它渲染成模型选择器里的 **Free** 标签页。
   所以"构建一个 cline-free 的 DeepSeek"在客户端侧**没有可配置项**——能不能用，取决于今天服务端发不发。

2. **截至 2026-10-12 实测，免费池里没有 DeepSeek。** 当前 `free` 池是：
   `cline-free/step-5-preview`、`cline-free/mimo-v2.6-flash`、`cline-free/muse-spark-1.3-contributor`、`cline-free/solar-mini4`。
   DeepSeek 目前只在这些地方：**ClinePass（订阅）**、**Cline Cloud**、**自带 key（BYOK）**。
   仓库里留有 `cline-free/deepseek-v4-flash` 这样的 ID（测试夹具 + 错误提示里的映射逻辑），说明 DeepSeek 系确实进过免费池，但**现在是轮换出去的状态**。

3. **如果你现在就要在 VS Code 里跑 DeepSeek，走"路线 B：自带 DeepSeek 官方 API key"**，
   5 分钟搞定、按量计费很便宜，而且不受推广轮换影响。想要"纯免费"就盯免费池（用下面的脚本），出现 DeepSeek 时在 Free 标签里选它。

| 路线 | 免费? | DeepSeek 可用? | 适合谁 |
|---|---|---|---|
| A. Cline 账号 + Free 标签（`cline-free/*`） | ✅ 完全免费（有每日额度） | ⚠️ 仅当推广池里恰好有 DeepSeek | 想零成本试用 |
| B. **BYOK：DeepSeek 官方 API key** | ❌ 按量付费（极便宜） | ✅ 稳定可用 | **想长期用 DeepSeek 的人（推荐）** |
| C. ClinePass 订阅 | ❌ $9.99/月 | ✅ `cline-pass/deepseek-v4.1-flash`、`cline-pass/deepseek-v4-pro` | 高频使用、想要高额度 |
| D. OpenRouter / 本地 Ollama | 部分免费 / 本地免费 | ✅ | 想要更多免费额度或完全离线 |

---

## 1. 先把概念捋清楚（含源码依据）

Cline 里跟"免费 / DeepSeek"相关的 provider 有三个，模型 ID 前缀各不相同：

| Provider（API Provider 下拉里） | 模型 ID 形态 | 说明 |
|---|---|---|
| **Cline**（usage-billing） | `cline-free/<slug>`、`<lab>/<model>` | 登录 Cline 账号即可用；**免费池挂在这里** |
| **ClinePass** | `cline-pass/<model>` | $9.99/月订阅；促销期也会带免费项 |
| **Cline Cloud** | `cline-cloud/<model>` | 服务端下发的实验/云侧模型，当前含 `cline-cloud/deepseek-v4.1-flash` |
| **DeepSeek**（BYOK） | `deepseek-flash`、`deepseek-v4-pro` … | 自带 DeepSeek 官方 key，base URL `https://api.deepseek.com/v1` |

关键机制（都能在 `cline/cline` 源码里对上）：

- **免费模型计费恒为 0**：`sdk/packages/llms/src/catalog/catalog-live.test.ts` 断言 `cline-free/*` 的 `pricing` 全为 0，且注释写明 *"free models are billed at $0 regardless of catalog pricing"*。
- **免费模型 slug 与付费模型同名**：`apps/vscode/webview-ui/src/components/chat/ClineFreeModelLimitError.tsx` 里的注释给出映射规则——
  `cline-free/deepseek-v4-flash` → `deepseek/deepseek-v4-flash`（即免费版用完可以一键切到同名付费版）。
- **免费池的来源接口**（客户端启动时拉取）：
  `GET https://api.cline.bot/api/v1/ai/cline/recommended-models`
  返回 `{recommended, free, clinePass, clineCloud}` 四个桶。**这个接口无需鉴权**，所以你可以随时自己查（见 §2 的自检脚本）。
- **免费额度是"每日"的**：错误文案是 *"Daily free model limit reached … try again in …"*（见 `apps/cli/src/utils/cline-pass-errors.ts`、`ClineFreeModelLimitError.tsx`）。
- **推广结束会变成 404**：模型被移出目录后，后端返回 `model not found`，插件会识别成 *"Free model promotion ended"*（`apps/vscode/src/services/error/ClineError.ts` 里的 `cline_free_promotion_ended`）。
- **免费模型只在 IDE 插件 / CLI 里有效**，官方明确说明 **不通过 Cline API 提供**。

---

## 2. 第一步：先确认"今天有没有免费 DeepSeek"

用仓库里带的自检脚本（`curl` + `jq`/`python3`，无需登录、无需 key）：

```bash
./scripts/check-cline-free-models.sh          # 人类可读
./scripts/check-cline-free-models.sh --quiet  # 只输出结论, 有 DeepSeek 时退出码 0
```

或者手工一条命令：

```bash
curl -s https://api.cline.bot/api/v1/ai/cline/recommended-models \
  | jq -r '.free[].id'
```

2026-10-12 的输出：

```text
cline-free/step-5-preview
cline-free/mimo-v2.6-flash
cline-free/muse-spark-1.3-contributor
cline-free/solar-mini4
```

→ 没有 DeepSeek，所以下面的**路线 A 现在选不到 DeepSeek**；要 DeepSeek 请直接跳到 **路线 B**。
（免费池轮换后，这个列表随时可能重新出现 DeepSeek 系模型，届时路线 A 自动可用。）

---

## 3. 路线 A：在 VS Code 里使用 Cline 免费池（DeepSeek 出现时怎么选它）

> 适合：零成本试用。前置条件只有一个——**一个免费的 Cline 账号**。

1. **装扩展**：VS Code 里 `Ctrl/Cmd+Shift+X` → 搜索 `Cline` → Install。
   （Marketplace 上的扩展 ID 是 `saoudrizwan.claude-dev`，需要 VS Code ≥ 1.101.0。）
2. **打开 Cline**：左侧活动栏点 Cline 图标（或 `Ctrl/Cmd+Shift+P` → `Cline: Open`）。
3. **进设置**：点 Cline 面板右上角的 **⚙️ 齿轮**。
4. **选 Provider**：把 **API Provider** 设为 **Cline**（即 usage-billing 那个，不是 ClinePass）。
5. **登录**：点 **Sign In**，浏览器里用 Google / GitHub / 邮箱完成 OAuth；回到 VS Code 应显示已登录账号。
   - 注意：**不登录是看不到 Free 模型的**。免费池是按账号下发的。
6. **打开模型选择器**：Cline 的模型选择器（设置页或聊天输入框上方的模型下拉）里有两个标签页：
   **Recommended** 和 **Free**（对应源码 `apps/vscode/webview-ui/src/components/settings/ClineModelPicker.tsx` 的 `activeTab: "recommended" | "free"`）。
   切到 **Free** 标签页 —— 这里列出的就是 `cline-free/*`，卡片上带 **FREE** 角标，价格显示 $0。
7. **选模型开始用**：DeepSeek 系出现在 Free 页时（名字形如 `DeepSeek … (free)`，ID 形如 `cline-free/deepseek-…`），选中它即可，然后正常发任务。

**小技巧 / 注意事项**

- 列表是启动时从服务端拉的，**推广轮换后不会立刻刷新**：`Ctrl/Cmd+Shift+P` → `Developer: Reload Window` 重载窗口，或重开设置页即可拿到最新免费池。
- 免费池有**每日额度**，用完当天会报 *"Daily free model limit reached … try again in X"*，此时可以：
  在错误卡片上一键切换到**同 slug 的付费模型**（如 `cline-free/deepseek-v4-flash` → `deepseek/deepseek-v4-flash`），或换另一个免费模型，或等窗口重置。
- 免费模型的用量**可能被用于改进模型质量**（官方说明），介意的话别用免费池。
- **免费模型不能通过 Cline API 调用**（只限 IDE 插件与 CLI）。想在脚本里用，只能走 BYOK 或 ClinePass + API key。

---

## 4. 路线 B（推荐）：在 VS Code 里接 DeepSeek 官方 API（BYOK）

> 适合：**现在就想稳定用 DeepSeek**。不受免费推广轮换影响，按量付费，DeepSeek 本身定价很便宜。

**Step 1 — 拿 key**

1. 打开 <https://platform.deepseek.com/>，注册/登录。
2. 进 **API keys**（<https://platform.deepseek.com/api_keys>）→ **Create new API key**，命名如 `cline`。
3. **立刻复制**（只显示一次），存到密码管理器。

**Step 2 — 在 Cline 里配置**

1. Cline 面板 → **⚙️ 设置** → **API Provider** 选 **DeepSeek**。
2. **API Key** 填刚复制的 key（会存进 VS Code SecretStorage / `~/.cline/data/settings/providers.json`）。
3. **Model** 从下拉里选，目录里 DeepSeek provider 提供的 id 是：
   - `deepseek-flash` → 显示名 *DeepSeek V4.1 Flash*，1M 上下文，支持图片/工具/推理/结构化输出，价格约 **$0.15 / $0.60**（每 1M tokens，输入/输出）
   - `deepseek-v4-pro` → 显示名 *DeepSeek V4 Pro*，1M 上下文，价格约 **$0.66 / $1.98**
   （DeepSeek 有非高峰折扣，实际账单可能更低；价格随官方调整，以 [DeepSeek 定价页](https://api-docs.deepseek.com/quick_start/pricing/) 为准。）
4. Base URL 默认 `https://api.deepseek.com/v1`，一般不用改。

**Step 3 — 验证**：发一句 `用一句话解释这个仓库是干什么的`，能流式返回即成功。

**等价做法（想要完全自定义时）**：把 API Provider 设为 **OpenAI Compatible**，
Base URL 填 `https://api.deepseek.com/v1`，API Key 填 DeepSeek key，**Model ID 手动输入**（如 `deepseek-chat`）。
Cline 里只有这几个 provider 允许手填任意模型 ID：`openai-compatible`、`ollama`、`lmstudio`、`litellm`、`vertex`
（见 `apps/vscode/src/sdk/model-catalog/custom-model-ids.ts`）。用它还可以指向任何 DeepSeek 兼容的第三方/自建网关。

**环境变量方式**（CLI / 自动化时有用）：`DEEPSEEK_API_KEY`（见 `sdk/packages/llms/src/providers/builtins.ts` 里 `deepseek` 的 `apiKeyEnv`）。

---

## 5. 路线 C：ClinePass 订阅（$9.99/月）

适合高频使用、想要高额度。步骤：在 [app.cline.bot 订阅页](https://app.cline.bot/dashboard/subscription?personal=true) 订阅 → Cline 设置里 **API Provider = ClinePass** → **Sign In** → 选模型。

当前 ClinePass 里的 DeepSeek：

| 模型 | ID | 参考单价（输入/输出，每 1M tokens） |
|---|---|---|
| DeepSeek V4.1 Flash | `cline-pass/deepseek-v4.1-flash` | $0.30 / $1.20 |
| DeepSeek V4 Pro（高峰/非高峰） | `cline-pass/deepseek-v4-pro` | $1.32 / $3.96（非高峰 $0.66 / $1.98） |

> 注意：**DeepSeek V4 Flash 已从 ClinePass 下架**（官方 deprecation 说明），替代品是 V4.1 Flash。
> ClinePass 的模型选择器同样有 **Subscribed / Free** 两个标签页，促销期免费项也会出现在这里。

---

## 6. 路线 D：其它能拿到 DeepSeek 的渠道

- **OpenRouter**：Cline 里 API Provider 选 **OpenRouter**，填 key，搜 `deepseek` 选型号（如 `deepseek/deepseek-v4-flash`、`deepseek/deepseek-v4-pro`）。
  2026-10-12 实测 OpenRouter 上 **DeepSeek 系列目前没有 `:free` 免费变体**，但单价很低（如 `deepseek/deepseek-v4-flash` ≈ $0.03 / 1M 输入）。
- **本地部署（零 token 成本）**：API Provider 选 **Ollama** / **LM Studio**，本地拉起 DeepSeek 蒸馏模型（如 `deepseek-r1` 系列）后即可离线使用；代价是显存/内存与速度。
- **Cline Cloud**：服务端下发桶里有 `cline-cloud/deepseek-v4.1-flash`，属于实验性入口，是否可用取决于账号灰度。


---

## 7. 排障：常见报错对照表

| 现象 / 报错 | 原因 | 处理 |
|---|---|---|
| Free 标签页是空的 / 看不到 FREE 模型 | 未登录 Cline 账号；或当前无有效推广 | 先 **Sign In**；再 `Developer: Reload Window` 刷新；用 §2 脚本确认服务端免费池是否为空 |
| `Daily free model limit reached … try again in X` | 当日免费额度用尽 | 等重置；或点错误卡片一键切到同 slug 付费模型；或换另一个免费模型 |
| `Free model promotion ended` / `Error 404: Model not found` | 该 `cline-free/*` 模型的推广期结束，已被移出目录 | 换模型（免费池里其它项），或切到同 slug 的付费版 |
| `401 Unauthorized: Please sign in` | 登录态过期 | 设置页重新 **Sign In**（必要时先 Sign Out） |
| 选了 DeepSeek 但请求 401/403 | DeepSeek key 错/欠费/被禁用 | 到 platform.deepseek.com 检查余额与 key 状态 |
| 模型下拉里没有我想要的 DeepSeek id | 该 provider 只暴露目录内的 id | 改用 **OpenAI Compatible** provider 手填 Model ID |
| 免费模型在 Cline API 里调不通 | 官方限制 | 免费模型仅限 IDE 插件与 CLI；API 请用 BYOK/ClinePass key |

**看日志**：VS Code `Ctrl/Cmd+Shift+P` → `Output: Show Output Channels` → 选 **Cline**（或 `Developer: Toggle Developer Tools` 看 Console）。

**手动/脚本化配置（进阶）**：Cline 的全局配置放在 `~/.cline/`（可用 `CLINE_DIR` 覆盖）：

```text
~/.cline/data/settings/providers.json        # provider / API key 配置
~/.cline/data/settings/global-settings.json  # 全局设置
~/.cline/data/logs/                          # 日志
```

CLI 侧可以用 `cline config` 交互式查看/编辑，或 `cline auth` 重新认证。
⚠️ 手工编辑前先备份；插件运行中改文件可能被覆盖，建议先退出 VS Code。

---

## 8. 如果你的"构建"指的是**从源码编译 Cline 插件**

自编译**不会**让你凭空多出免费 DeepSeek —— 免费池由服务端按账号发放，改本地代码只能改 UI 展示。但如果你想在源码里调试/接自己的模型，步骤如下：

```bash
# 依赖：bun 1.4.2、Node >= 22（仓库根 package.json 里 engines 指定）
git clone https://github.com/cline/cline.git && cd cline
bun install

# 方式一：开发调试（esbuild watch + tsc watch），然后在 VS Code 里 F5 启动 Extension Development Host
bun -F @cline/vscode dev

# 方式二：生产构建（webview + esbuild --production）
bun -F @cline/vscode build:production
# 打包 vsix：bun -F @cline/vscode run vscode:prepublish 后使用 vsce package
```

要点：

- 插件的 provider/模型目录来自 SDK 包 `@cline/llms`：`sdk/packages/llms/src/catalog/catalog.generated.ts`（内置目录）+
  `catalog-live.ts`（启动时拉 `recommended-models` 覆盖）。**免费池就是 `catalog-live` 合并进来的 `free` 桶。**
- 想接自己的 DeepSeek 网关：改 provider 的 `defaults.baseUrl`（`sdk/packages/llms/src/providers/builtins.ts` 里 `deepseek` 条目）或用 OpenAI Compatible。
- 想自造"免费"体验（本地/内网）：把 `cline-free/*` 那套前缀理解成"计费置 0 + 目录注入"即可——
  即在你自己的网关里返回同名模型并计费 0，然后在 Cline 里用 OpenAI Compatible 指向它。注意这**只是绕过 Cline 的计费展示**，与官方免费推广无关。

---

## 9. 不推荐但确实存在：把"免费额度"转成 API 的第三方项目

社区里有把 Cline 免费模型额度包装成 OpenAI/Anthropic 兼容 API 的项目（例如 `ClineFreePool`、`clinefree-plugin` 之类，
用多账号池 + 令牌轮换来放大免费额度）。**不建议使用**：

- 大概率违反 Cline 服务条款，账号可能被封；
- 免费池本身随时轮换/限额，这类项目极易失效；
- 需要把 Cline 账号的 refresh token 交给第三方脚本，等于交出账号。

如果只是想在脚本里用 DeepSeek，**花几毛钱用官方 BYOK 更省事**。

---

## 10. 参考与证据

**官方文档**

- Cline Free Models：<https://docs.cline.bot/getting-started/free-models>
- Cline（usage-billing）：<https://docs.cline.bot/getting-started/cline-provider>
- ClinePass（含 DeepSeek 型号与参考价）：<https://docs.cline.bot/getting-started/clinepass>
- DeepSeek BYOK 配置：<https://docs.cline.bot/provider-config/deepseek>
- 授权与模型选择：<https://docs.cline.bot/getting-started/authorizing-with-cline>
- 配置文件位置：<https://docs.cline.bot/getting-started/config>

**实时接口（本文结论的数据来源）**

```bash
curl -s https://api.cline.bot/api/v1/ai/cline/recommended-models | jq '{free, clinePass, clineCloud}'
```

**源码位置（`cline/cline`）**

| 事实 | 文件 |
|---|---|
| 免费池接口与合并逻辑 | `sdk/packages/llms/src/catalog/catalog-live.ts`、`catalog-cline-recommended.ts` |
| 免费模型计费为 0 | `sdk/packages/llms/src/catalog/catalog-live.test.ts` |
| `cline-free/` 前缀与"推广结束"识别 | `apps/vscode/src/services/error/ClineError.ts`、`apps/cli/src/utils/cline-pass-errors.ts` |
| 免费额度错误与一键切付费模型 | `apps/vscode/webview-ui/src/components/chat/ClineFreeModelLimitError.tsx`、`ClineFreePromotionEndedError.tsx` |
| 模型选择器的 Recommended / Free 标签 | `apps/vscode/webview-ui/src/components/settings/ClineModelPicker.tsx` |
| DeepSeek provider 定义（baseUrl / env） | `sdk/packages/llms/src/providers/builtins.ts` |
| 允许手填模型 ID 的 provider | `apps/vscode/src/sdk/model-catalog/custom-model-ids.ts` |

> ⚠️ **时效性**：免费池是"限时轮换"的，本文关于"当前免费池里没有 DeepSeek"的结论只对应 2026-10-12。
> 换一天请先跑 `./scripts/check-cline-free-models.sh` 再照路线 A 操作。

