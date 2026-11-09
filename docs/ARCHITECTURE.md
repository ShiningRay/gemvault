# Gemvault 架构方案

- 状态：Proposed
- 日期：2026-11-10
- 对应阶段：设计基线，尚未实现 Registry 功能

## 1. 背景与决策摘要

Gemstash 使用 Ruby、Sinatra/Rack 和 Puma，同时提供公共 Gem 缓存与私有 Gem 托管。Gemvault 的目标是使用 Crystal 重新实现这组常见客户端工作流，并改善大文件传输、冷缓存并发、协议正确性和运维可观测性。

这不是 Ruby 代码的逐行移植。实现依据是 RubyGems 的公开协议、Gemstash 的可观察行为和真实客户端测试。

核心决策：

1. 使用 Crystal 标准库 `HTTP::Server` 和显式路由，暂不引入 Web 框架；
2. 首版单实例，使用 SQLite 保存私有元数据/索引和本地磁盘保存 Gem 文件；
3. 公共 Compact Index 采用字节保真代理，私有 Compact Index 由本地数据生成；
4. `.gem` 上传采用受限的 Ruby Marshal 解析，不依赖 Ruby 进程；
5. 公共源与 `/private` 私有源严格隔离，不合并依赖解析结果；
6. 先通过真实 Bundler/RubyGems 测试，再宣传协议兼容或性能优势。

## 2. 范围与优先级

| 优先级 | 功能 | 说明 |
| --- | --- | --- |
| P0 | 公共 Gem 缓存 | `/gems/:id` 回源、落盘和读取 |
| P0 | 公共 Compact Index | `/versions`、`/info/:name`，含 Range、ETag、Digest |
| P0 | 私有 Gem 发布与下载 | `/private/api/v1/gems`、`/private/gems/:id` |
| P0 | 私有 Compact Index | 让当前支持的 Bundler 能解析私有 Gem |
| P0 | 认证 | 哈希存储的分权 API Key，私有读取可配置为强制认证 |
| P1 | 版本撤回 | 保留文件但移出可解析索引，禁止同版本重新发布 |
| P1 | Legacy Index | RubyGems 旧客户端需要的 specs/gemspec.rz |
| P2 | 可观测性与运维 | 指标、备份恢复、优雅停止、压测报告 |

Legacy Dependency API 只用于需要它的旧客户端，不作为主路径；该 API 已从 rubygems.org 下线，不能依赖公共上游提供。

## 3. 总体结构

```text
Bundler / RubyGems / gem push
              |
         Reverse proxy
     TLS / limits / access logs
              |
       Crystal HTTP server
              |
        Explicit router
       /              \
 Public source      Private source (/private)
       |              |
 Upstream allowlist  Authentication / authorization
       |              |
 Metadata proxy      Gem parser + registry service
       |              |
 File cache          SQLite metadata + file objects
       |              |
 Single-flight       Atomic publish + index rebuild
       \              /
        Streaming response
```

代码边界：

```text
src/
  gemvault.cr                 库入口
  cli.cr                      CLI 与服务组合入口
  gemvault/
    config.cr                 配置加载、校验、脱敏
    router.cr                 路由与统一错误映射
    http/
      upstream_client.cr      有界上游请求与超时
      response.cr             流式响应、HEAD、缓存头
    public/
      source.cr               公共源只读工作流
      compact_index_proxy.cr  Range/ETag/Digest 保真
    private/
      source.cr               私有源路由入口
      registry.cr             发布、撤回、读取事务
      compact_index.cr        私有索引生成与原子替换
      authorizer.cr           API Key 权限校验
    package/
      reader.cr               tar/gzip 包结构读取
      marshal/                有界 Ruby Marshal 子集
      specification.cr        规范化 Gem 元数据
    storage/
      database.cr             SQLite 与迁移
      object_store.cr         文件对象与原子写入
    observability.cr          日志、健康与指标
spec/
  unit/                       纯函数与组件测试
  contract/                   真实客户端协议验收
  integration/                上游替身、并发与故障注入
  fixtures/                   可重建的小型测试 Gem
```

依赖方向为 `router → application services → storage/package/upstream`。存储和 HTTP 客户端不反向依赖路由，测试通过接口注入替身。

## 4. 公共源设计

### 4.1 上游选择

首版只支持配置中的默认上游，默认 `https://rubygems.org`。不实现 `/upstream/:url` 和 `/redirect/:url`。

原因：由请求路径直接指定任意上游会形成 SSRF 与开放代理面，也会把凭据放入 URL。后续若支持多个上游，必须使用服务端命名配置和 allowlist，并禁止重定向越出 allowlist。

`X-Gemfile-Source` 等来源信息先作为可观测字段处理，不允许改变请求目标；只有显式实现多上游契约后才能参与路由。

### 4.2 Gem 文件缓存

`GET /gems/:id`：

1. 严格校验文件名，拒绝路径分隔符、NUL、非规范后缀和超长输入；
2. 根据“上游 ID＋完整文件名”查找本地对象；
3. 命中时流式返回文件，保留必要的缓存与校验头；
4. 未命中时按资源键进行 single-flight，只让一个 fiber 回源；
5. 先写同文件系统临时文件，同时计算 SHA-256；
6. 完成并校验后原子 rename 为 immutable 对象，再响应客户端；
7. 失败或客户端断开时清理临时文件，不暴露不完整对象；
8. 等待同一资源的结果可直接共享已落盘对象，不能重复写最终路径。

Gem 文件视为不可变对象。缓存的 HTTP 头与正文需要明确一致性规则，不能把一次未完成的响应元数据当成已提交缓存。

首版采用直写缓存模式，并测量等待回源时的尾延迟。若回源故障导致大量等待，再评估“后台写缓存＋流式转发”，不能提前引入双写复杂度。

### 4.3 Compact Index 代理

公共 `/versions` 和 `/info/:name` 必须优先保证字节级 HTTP 语义：

- 上游成功时透传状态、正文以及必要的 `Content-Type`、`ETag`、`Last-Modified`、`Cache-Control`、`Accept-Ranges`；
- `Range`、`If-Range`、`If-None-Match` 按契约转发，保留 `206`、`304`、`416`；
- `Repr-Digest` 必须对应**完整表示**，不可误用本次 `206` 分片的摘要；
- 旧 `Digest` 头如存在则透传，但新实现只依赖 `Repr-Digest`；
- 透传 `Vary`，请求压缩时保持编码、长度和摘要语义一致；首选转发未编码表示，避免缓存错误；
- 不缓存上游错误、空响应、被截断的正文或校验失败的表示；
- 不在反向代理/CDN 中独立混用不同时间的 `/versions` 和 `/info/*` 缓存。

元数据缓存分两层：

1. **缓存响应元数据**：帮助重新验证与故障诊断；
2. **可选快照**：保存完整且经校验的上游表示，仅用于明确的 stale-if-error 策略。

不能简单缓存一个 `206` 分片作为完整文件。若实现增量更新，必须从正确偏移追加，并对最终完整表示计算 SHA-256，与 `Repr-Digest` 比较；不一致则丢弃并重新拉取完整文件。

第一版公共索引可采用“实时代理＋有限元数据缓存”，把离线索引服务作为后续独立验收项。

### 4.4 故障策略

- 上游连接、读取、空闲连接分别设置超时；
- 只对安全的网络错误进行有限重试，不盲目重放非幂等操作；
- 将上游 `429` 和 `5xx` 映射为可诊断响应，保留 `Retry-After`，不伪装成成功；
- 冷缓存且上游失败时返回 `502/504`；离线可用是拥有完整快照后的独立能力；
- 熔断、重试预算与 stale-if-error 必须可观测，不能静默长期提供过期索引。

## 5. 私有源设计

### 5.1 上传流水线

`POST /private/api/v1/gems`：

1. 认证 `push` 权限；认证失败不读取完整请求体；
2. 通过 `Content-Length` 和流式读取限制包大小；
3. 写入临时文件并计算 SHA-256，避免整个 Gem 常驻内存；
4. 仅读取外层 tar 的 `metadata.gz`，限制解压尺寸、条目数和读取深度；
5. 用受限 Ruby Marshal 读取器提取所需字段，不实例化任意 Ruby 对象；
6. 规范化为 name、version、platform、dependencies、required Ruby/RubyGems 等；
7. 检查名称、版本、平台与文件名的一致性，拒绝同版本不同内容的覆盖；
8. 在一个数据库事务中登记版本与依赖，生成索引；
9. 原子提交 Gem 对象和索引，清理临时文件；
10. 记录审计事件，但不记录 API Key、Authorization 或完整凭据 URL。

### 5.2 Ruby Marshal 风险与策略

`.gem` 当前包体是 tar，包含 `metadata.gz`、`data.tar.gz` 等。RubyGems 会将 specification 序列化，Legacy `quick/Marshal.4.8/*.gemspec.rz` 需要 deflate 的 Marshal specification。

实现不能假设 metadata 永远是 YAML，也不能仅依赖文件名识别 Gem。计划实现有边界的 Ruby Marshal 子集：

- 支持 `Gem::Specification` 及所需关联对象；
- 支持必要的对象、实例变量、字符串、符号、数组、Hash、数值和链接类型；
- 限制对象数、容器深度、字符串/数组长度、引用数和总解析时间；
- 遇到未知类型或保留字段时保留原始必要信息或明确拒绝，不能静默生成错误索引；
- 提供跨 Ruby/RubyGems 版本生成的测试 fixtures；
- 对 malformed input、压缩炸弹和递归结构进行模糊测试。

`crystal-ruby-marshal` 可作为协议研究参考，但其文档标注为实验项目且尚不支持完整 dump，首版不将其作为关键路径依赖。

### 5.3 私有 Compact Index

私有 `/versions`、`/info/:name` 由已提交元数据生成：

- 每个 Gem 的 `/info` 是完整快照，更新时整体重建；
- `/versions` 首版可整体重建，通过 ETag 与完整 SHA-256 降低重复下载；
- 输出格式以当前 Bundler Compact Index 实现为验收标准，包括 platform、依赖、SHA-256 `checksum` 和发布时间 `created_at`；
- 首个发布版本使用 Compact Index v2 格式，使 Bundler cooldown 能识别私有 Gem 的发布时间；
- 索引内容写入临时文件，校验后原子替换；
- 数据库保存索引版本或内容摘要，使恢复时能发现缺失/陈旧索引；
- 客户端永远只能看到上一代或新一代完整快照，不能看到半个文件。

若私有 `/versions` 增长后需要 append-only/Range 增量，再引入代际和追加记录；不要在首版用“整文件替换＋支持 Range”制造不一致。

私有源与公共源各自解析依赖。私有 Gem 的公共依赖不应自动进入公共源解析上下文；客户端需要按 RubyGems/Bundler 的 source 规则声明依赖来源。

### 5.4 版本撤回与不可变性

`DELETE /private/api/v1/gems/yank` 需要 `yank` 权限：

- 将对应版本标为 yanked 并从索引移除；
- 文件保留用于审计，默认不再提供普通下载；
- 相同 name/version/platform 永不允许重新发布；
- 并发 push/yank 在数据库约束和事务下只有一个明确结果；
- 不提供“同版本替换内容”的快捷选项。

## 6. 存储与一致性

### 6.1 数据布局

```text
data/
  gemvault.db
  objects/
    public/<upstream-id>/<shard>/<filename>
    private/<shard>/<full-name>.gem
  index/
    private/versions
    private/info/<name>
  tmp/
```

首版只支持本地文件系统单实例。路径由规范化元数据和安全映射生成，不能将上传的任意路径拼入文件系统。

### 6.2 SQLite

启用 foreign keys、WAL 和 busy timeout。主要表：

- `gems(id, name, created_at)`；
- `versions(id, gem_id, version, platform, sha256, size, state, created_at, yanked_at)`；
- `dependencies(version_id, name, requirements, scope)`；
- `api_keys(id, name, key_digest, key_prefix, scopes, created_at, revoked_at)`；
- `schema_migrations(version)`；
- 可选 `audit_events`、`upstream_cache_metadata`。

唯一约束至少覆盖 `(gem_id, version, platform)`。key_digest 必须唯一；按 key_prefix 查询候选后再进行慢哈希验证，避免全表明文比较。

### 6.3 崩溃恢复

服务启动时扫描未完成临时文件，并依据数据库和对象存储核对发布状态。恢复规则必须区分“对象已落盘但事务未提交”和“事务已提交但索引未替换”，并分别测试。

首版明确选择一种可恢复提交顺序，例如“对象落盘 → DB 事务 → 索引原子替换”，启动时从已提交 DB 重建索引。不得在文档中仅写“原子发布”而没有跨文件/DB 的恢复设计。

## 7. 认证与安全

- 使用 `fetch`、`push`、`yank` 最小权限；管理 Key 的权限单独设计；
- 支持 RubyGems `Authorization: <key>`，以及兼容 Gemstash 的 Basic 用户名形式；
- 仅存储带独立盐的慢哈希（优先 Argon2id，若选型受限则明确 PBKDF2 参数）；不存明文或 SHA-256(key)；
- 比较使用恒定时间实现，支持撤销和轮换；
- 凭据仅通过环境变量、secret 文件或交互式管理命令注入；
- 日志对 Authorization、Cookie、userinfo、配置敏感字段脱敏；
- 生产由反向代理提供 HTTPS，服务默认只监听 loopback；
- 私有读取默认要求认证；匿名读取必须显式配置；
- 限制请求体、Header、包大小、解压尺寸、并发回源和上游重定向；
- 公共代理不能读取私有对象，私有路径不能逃逸到对象根目录之外。

反向代理需要限制请求体、正确传递 Host/scheme，并避免公开管理接口。服务不盲目信任任意客户端传入的 `X-Forwarded-*`。

## 8. 性能策略

Crystal 编译为原生代码并使用 fiber 调度 I/O，但这本身不保证 Registry 更快。性能目标必须来自测量。

设计手段：

- 上传、下载、上游转发均采用定长 buffer 流式处理；
- 大文件不把完整内容读入 `String` 或 `Bytes`；
- 公共冷缓存使用资源级 single-flight 和有界并发队列；
- 数据库只存元数据，不保存大对象 Blob；
- 热路径减少重复 stat、哈希和索引重建；
- 以本地磁盘、网络和上游延迟解释瓶颈，不用 Hello World QPS 代替 Gem 工作负载；
- 多线程和 CPU 并行是后续配置与压测决策，不作为首版承诺。

必须分别测量冷缓存、热缓存、索引 revalidation、私有上传和并发推送，记录吞吐、P50/P95/P99、内存、磁盘与失败率。

## 9. 可观测性与运维

结构化日志至少包含 request_id、route、source、result、duration、bytes、cache_status、upstream_status；不包含密钥。

健康检查：

- `/health/live`：进程存活，不访问 DB/磁盘；
- `/health/ready`：配置、数据库、数据目录可用；
- 不在健康检查中访问 rubygems.org。

后续指标：请求延迟与数量、缓存命中/回源、single-flight 等待、上游状态、对象字节数、索引重建失败、DB 错误。

部署提供 Linux systemd/container 示例、非 root 用户、只读根文件系统＋显式可写数据目录、备份与恢复步骤。首版不支持多实例同时写 SQLite 或共享本地目录。

## 10. 关键取舍

| 方案 | 决定 | 理由 |
| --- | --- | --- |
| 标准库 HTTP vs Kemal | 标准库 | 路由有限，减少关键路径依赖和框架行为不确定性 |
| SQLite vs PostgreSQL | 首版 SQLite | 单实例运维简单；接口隔离，后续再支持外部 DB |
| 公共索引重写 vs 保真代理 | 保真代理 | 降低 Range/Digest 与上游协议偏差 |
| Ruby Marshal 子集 vs Ruby sidecar | 原生有界解析 | 保持单一服务与部署简单，接受实现和测试成本 |
| 直接回源 vs 预同步全站 | 按需回源 | 降低存储和同步复杂度 |
| 多上游 URL vs 固定上游 | 首版固定上游 | 避免开放代理、SSRF 和 URL 凭据 |

## 11. 参考资料

- [Gemstash README](https://github.com/rubygems/gemstash)
- [Gemstash private gems](https://github.com/rubygems/gemstash/blob/main/docs/gemstash-private-gems.7.md)
- [RubyGems Compact Index API](https://guides.rubygems.org/rubygems-org-compact-index-api/)
- [Bundler Compact Index updater](https://github.com/ruby/rubygems/blob/master/lib/bundler/compact_index_client/updater.rb)
- [RubyGems package reader](https://github.com/ruby/rubygems/blob/master/lib/rubygems/package.rb)
- [Crystal HTTP server](https://crystal-lang.org/api/latest/HTTP/Server.html)
- [Crystal SQLite3 driver](https://github.com/crystal-lang/crystal-sqlite3)
