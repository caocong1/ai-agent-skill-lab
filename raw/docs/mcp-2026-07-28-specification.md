# MCP 规范 2026-07-28 修订结构化摘要

- 来源 URL：https://modelcontextprotocol.io/specification/2026-07-28/changelog
- 上一版本：2025-11-25（https://modelcontextprotocol.io/specification/2025-11-25）
- 发布日期：2026-07-28
- 抓取日期：2026-08-23
- 抓取方式：官方规范站点只读抓取（WebFetch）
- 版权说明：本文档是基于官方 changelog 与规范页的中文结构化转述，不是原文镜像，不包含大段逐字复制。方法名、字段名、错误码等标识符按原样保留，因为它们是事实而非表达。

## 一句话概括

这一版把 MCP 从"有会话、有握手、服务端可反向发起请求"的有状态协议，改成了**无状态、单向请求-响应**的协议：删掉 `initialize` 握手与 `Mcp-Session-Id`，把协议版本与客户端能力塞进每个请求的 `_meta`，并用 MRTR（多轮往返请求）取代服务端反向调用。

## 重大变更

### 1. 删除协议级会话

- 移除 Streamable HTTP 传输里的 `Mcp-Session-Id` 头。
- `tools/list` / `resources/list` / `prompts/list` 的返回**不再随连接变化**。
- 需要跨调用状态的服务端，改为由服务端铸造显式句柄（handle），作为**普通的 tool 参数**传递。
- 依据：SEP-2567。

### 2. 无状态化：删除握手

- 移除 `initialize` 请求与 `notifications/initialized` 通知。
- 每个请求在 `_meta` 里自带：
  - `io.modelcontextprotocol/protocolVersion`（协议版本）
  - `io.modelcontextprotocol/clientCapabilities`（客户端能力）
  - `io.modelcontextprotocol/clientInfo`（客户端身份，SHOULD）
- 服务端 SHOULD 在**每个结果**的 `_meta` 里回报 `io.modelcontextprotocol/serverInfo`。
- 版本不匹配返回 `UnsupportedProtocolVersionError`。
- 依据：SEP-2575。

### 3. 新增 `server/discover`

- 服务端 **MUST** 实现，用于公布支持的协议版本集合、能力与身份。
- 客户端 **MAY** 在任何其他请求之前调用它做前置版本协商，或在 STDIO 上把它当作向后兼容探针。
- 依据：SEP-2575。

### 4. `subscriptions/listen` 取代 GET 端点与 `resources/subscribe`

- 移除 HTTP GET 端点、`resources/subscribe`、`resources/unsubscribe`。
- 改为单条长连接的 POST 响应流，客户端**显式订阅**具体类型：`toolsListChanged`、`promptsListChanged`、`resourcesListChanged`、`resourceSubscriptions`。
- 服务端确认订阅，并用 `io.modelcontextprotocol/subscriptionId` 给通知打标。
- **请求作用域的通知不走这条流**：`notifications/progress`、`notifications/message` 仍然走它们所属请求自身的响应流。
- 依据：SEP-2575。

### 5. 删除 `ping` / `logging/setLevel` / `notifications/roots/list_changed`

- 日志级别改为**按请求设置**：`_meta` 里的 `io.modelcontextprotocol/logLevel`。
- 服务端 **MUST NOT** 对没有携带该字段的请求发出 `notifications/message`。
- 依据：SEP-2575。

### 6. Tasks 移出核心，成为官方扩展

- 扩展命名空间：`io.modelcontextprotocol/tasks`。
- 阻塞式的 `tasks/result` 被**轮询式 `tasks/get`** 取代。
- 新增 `tasks/update`：客户端向服务端投递输入。
- 移除 `tasks/list`。
- 服务端可以**不经每请求 opt-in**就返回 task handle。
- 依据：SEP-2663。

### 7. MRTR（Multi Round-Trip Requests）取代服务端反向请求

- 取代原先的服务端发起请求路径：`roots/list`、`sampling/createMessage`、`elicitation/create`。
- 服务端返回 `InputRequiredResult`（`resultType: "input_required"`），其 `inputRequests` 字段携带它还需要的信息。
- 客户端在**重试原请求**时带上 `inputResponses` 作答。
- 依据：SEP-2322。

### 8. 所有结果必须带 `resultType`

- `"complete"`：普通结果。
- `"input_required"`：MRTR 中间结果。
- 客户端 **MUST** 把老协议服务端省略该字段的结果按 `"complete"` 处理。
- 依据：SEP-2322。

### 9. 删除 SSE 流可恢复性与消息重投

- 移除 `Last-Event-ID` 头与 SSE event id。
- 响应流断开即丢失该在途请求；客户端 **MUST** 用**新的 request id** 作为一个新请求重发。
- 依据：SEP-2575。

## 次要变更

1. `ClientCapabilities` / `ServerCapabilities` 新增 `extensions` 字段，支撑核心协议之外的扩展。
2. 约定 OpenTelemetry trace context 在 `_meta` 里的键：`traceparent`、`tracestate`、`baggage`（SEP-414）。
3. 服务端 **SHOULD** 让 `tools/list` 以**确定性顺序**返回工具，理由写得很直白：便于客户端缓存，并**提高 LLM prompt cache 命中率**。
4. Streamable HTTP POST 请求必须带标准头 `Mcp-Method`、`Mcp-Name`；新增从 tool 参数注入自定义头的 `x-mcp-header`（SEP-2243）。
5. 新增 `CacheableResult` 接口，`tools/list`、`prompts/list`、`resources/list`、`resources/read`、`resources/templates/list` 的结果**必须**带：
   - `ttlMs`：新鲜度提示（毫秒），让客户端缓存并减少轮询；
   - `cacheScope`：`"public"` 或 `"private"`，控制共享中间层能否缓存。
   两者与既有的 `listChanged` 通知互补而非替代（SEP-2549）。
6. resource not found 的错误码从 `-32002` 改为 `-32602`（Invalid Params），与 JSON-RPC 对齐。
7. 授权服务器 **SHOULD** 在授权响应里带 `iss`（RFC 9207）；MCP 客户端 **MUST** 在兑换授权码前把出现的 `iss` 与已记录的 issuer 校验一致（SEP-2468）。
8. 动态客户端注册（DCR）时客户端必须指定合适的 `application_type`，以避免 OpenID Connect 重定向 URI 冲突（SEP-837）。
9. 客户端凭据**绑定到签发它的授权服务器**：MUST 以 issuer 标识为键持久化，MUST NOT 换一个授权服务器复用，授权服务器变更时 MUST 重新注册（SEP-2352）。
10. `inputSchema` / `outputSchema` 放宽到允许任意 JSON Schema 2020-12 关键字，`structuredContent` 允许任意 JSON 值；同时新增 `$ref` 解析要求与组合关键字的资源上界（SEP-2106）。
11. 删除 2025-11-25 引入的 `notifications/elicitation/complete` 通知与 URL 模式 elicitation 的 `elicitationId` 字段。理由：在 MRTR 下客户端是靠**重试原请求**得知带外交互结果的，服务端发起的完成信号与用于关联的标识符都不再契合协议；服务端若需跨重试关联，自行在 `requestState` 里编码标识符。
12. 定义**错误码分配政策**，切分 JSON-RPC server-error 区间：
    - `-32000` ~ `-32019`：实现自定义（现有 SDK 用法既往不咎）；
    - `-32020` ~ `-32099`：保留给 MCP 规范。
    据此重编本轮草案引入的码：`HeaderMismatch` `-32001` → `-32020`，`MissingRequiredClientCapability` `-32003` → `-32021`，`UnsupportedProtocolVersion` `-32004` → `-32022`；并把此前只存在于传输层散文里的 `HeaderMismatchError` 补进 schema。

## 弃用（仍在规范内，但按弃用政策排期移除）

1. **Roots、Sampling、Logging 三个特性整体弃用**（SEP-2577）。弃用窗口内仍完全可用，但新实现不应再支持。官方建议的迁移路径：
   - Roots → 通过 tool 参数、resource URI 或服务端配置传目录/文件；
   - Sampling → 直接对接 LLM 供应商 API；
   - Logging → stdio 下写 `stderr`，或改用 OpenTelemetry。
2. HTTP+SSE 传输（自 `2025-03-26` 起已标记 deprecated）按特性生命周期政策重新归类为 Deprecated，迁移到 Streamable HTTP（SEP-2596）。
3. `includeContext` 的 `"thisServer"` / `"allServers"` 取值重新归类为 Deprecated；omit 或用 `"none"`，其移除不晚于 Sampling 本身（SEP-2596）。
4. OAuth 2.0 动态客户端注册（RFC 7591）作为注册机制被弃用，改用 **Client ID Metadata Documents**；为兼容不支持后者的授权服务器而保留（PR #2858）。

## Schema 其他变更

- `schema.json` 修正：TypeScript 定义里的 minimum / maximum / default 是 `number` 而非 `integer`（此前是生成器带了 `--defaultNumberType integer` 导致的偏差，PR #2710）。

## 治理与流程

1. 采纳**特性生命周期与弃用政策**：定义 Active / Deprecated / Removed 三态，**最短 12 个月**弃用窗口，并维护一份已弃用特性登记表（SEP-2596）。
2. SEP 流程 PR 化：`seps/` 目录下的 markdown 文件、由 PR 派生的编号、明确的 sponsor 职责、用 PR label 管理状态（SEP-1850）。
