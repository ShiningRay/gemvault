# RubyGems 协议兼容矩阵

- 状态：目标契约，未标记为已实现
- 最后更新：2026-11-10

## 1. 定义

本项目的“协议兼容”以真实客户端完成工作流为准，而不是声称复制 Gemstash 的全部内部行为。

- **MVP**：进入第一个可测试版本前必须完成；
- **P1**：首个稳定版本目标；
- **备选**：另行设计和决策，不默认承诺；
- **不支持**：明确排除。

所有返回码和 Header 都需要 contract tests 固定。`/private` 前缀不能被内部重写到公共源后绕过认证。

## 2. 公共源

| 接口/行为 | 范围 | 实现状态 | 验收重点 |
| --- | --- | --- | --- |
| `GET/HEAD /versions` | MVP | 计划中 | 200/206/304/416、Range、ETag、完整 Repr-Digest |
| `GET/HEAD /info/:name` | MVP | 计划中 | 名称校验、增量更新、304、字节保真 |
| `GET/HEAD /names` | P1 | 计划中 | 代理语义与内容类型 |
| `GET/HEAD /gems/:id` | MVP | 计划中 | 热缓存、冷回源、single-flight、SHA-256、HEAD |
| `GET /latest_specs.4.8.gz` | P1 | 计划中 | 旧 RubyGems 安装流程 |
| `GET /specs.4.8.gz` | P1 | 计划中 | 大索引流式代理与失败处理 |
| `GET /prerelease_specs.4.8.gz` | P1 | 计划中 | 同上 |
| `GET /quick/Marshal.4.8/:id` | P1 | 计划中 | 旧客户端 gemspec 获取 |
| `/api/v1/dependencies` | 备选 | 未设计 | 上游已下线；只能自行生成或明确不支持 |
| `/upstream/:url` | 不支持 | 排除 | 避免任意 URL 开放代理和 SSRF |
| `/redirect/:url` | 不支持 | 排除 | 非核心缓存工作流 |
| `X-Gemfile-Source` | 首版只记录 | 计划中 | 首版不能据此访问任意上游 |

首版默认上游为 `https://rubygems.org`。多上游若加入，必须采用服务端命名 allowlist。

## 3. 私有源

| 接口/行为 | 范围 | 实现状态 | 验收重点 |
| --- | --- | --- | --- |
| `POST /private/api/v1/gems` | MVP | 计划中 | `gem push --host .../private`、分权、限流、包校验 |
| `GET/HEAD /private/gems/:id` | MVP | 计划中 | `gem install`、私有读取认证、404/403 语义 |
| `GET /private/versions` | MVP | 计划中 | 索引正确、平台、版本撤回、完整摘要 |
| `GET /private/info/:name` | MVP | 计划中 | 依赖格式、SHA-256 checksum、v2 `created_at`、更新一致性 |
| `GET /private/names` | P1 | 计划中 | 仅列私有 Gem |
| `DELETE /private/api/v1/gems/yank` | P1 | 计划中 | `gem yank`、索引更新、不可重新发布 |
| `GET /private/specs.4.8.gz` | P1 | 计划中 | 旧 RubyGems 与 Marshal specification |
| `GET /private/latest_specs.4.8.gz` | P1 | 计划中 | 最新非预发布版本筛选 |
| `GET /private/prerelease_specs.4.8.gz` | P1 | 计划中 | 预发布版本筛选 |
| `GET /private/quick/Marshal.4.8/:id` | P1 | 计划中 | 原生 Marshal dump＋deflate 与 Ruby 对照 |
| `/private/api/v1/add_spec.json` | 不支持 | 排除 | Gemstash 本身未支持该私有接口 |
| `/private/api/v1/remove_spec.json` | 不支持 | 排除 | 同上 |

## 4. 认证与权限

| 能力 | MVP 目标 | 验证 |
| --- | --- | --- |
| `Authorization: <api-key>` | 支持 | `gem push` 真实客户端 |
| Basic 用户名作为 API Key | 支持 | Bundler 私有源拉取 |
| `fetch` 权限 | 支持 | 私有元数据、Gem 文件均受保护 |
| `push` 权限 | 支持 | 只有 push 不能 fetch/yank |
| `yank` 权限 | P1 | 只有 yank 不能 push |
| Key 撤销与轮换 | MVP | 撤销立即失败，日志无明文 |
| 匿名私有读取 | 默认关闭 | 显式配置才允许 |
| 管理 API | 首版本地 CLI | 管理端口不暴露公网 |

## 5. HTTP 正确性清单

- 所有 GET 路由评估 HEAD 行为，响应不带正文但保留正确元数据；
- Range 偏移使用字节，不将编码后的分片拼到未编码正文；
- `206` 响应的 `Repr-Digest` 对应完整表示；
- 客户端缓存与上游缓存不会在索引代际之间混合；
- 不缓存 4xx/5xx、截断响应、摘要错误和未写完的临时文件；
- 401 带合适的 `WWW-Authenticate`，403 用于已认证但权限不足；
- 重复 push 返回冲突类错误，不覆盖原 Gem；
- 私有 yanked 版本不出现在新索引；
- 上游重定向遵循协议、目标和凭据 allowlist；
- 错误响应不包含上游凭据、绝对数据路径或内部堆栈。

## 6. 客户端验收矩阵

| 测试 | 客户端 | 上游状态 | 通过条件 |
| --- | --- | --- | --- |
| 公共冷缓存安装 | 支持的 Bundler 当前稳定版＋一个旧版 | 测试上游可用 | 完整 `bundle install`，二次请求命中 Gem 缓存 |
| 公共热缓存安装 | 同上 | 文件缓存存在 | 相同 lockfile 成功，无重复 Gem 下载 |
| Compact Index 增量 | Bundler | 上游追加版本 | 不破坏本地索引，checksum 校验成功 |
| 上游故障 | Bundler | 超时、429、502 | 无损坏缓存，错误可诊断 |
| 私有发布 | RubyGems `gem push` | 本地 | 成功上传，拒绝重复版本 |
| 私有安装 | RubyGems `gem install` | 本地 | 仅授权 Key 可安装 |
| 私有 Bundler 安装 | Bundler | 本地 | 独立 private source block 安装成功 |
| 平台 Gem | 两种客户端 | 本地 | ruby/非 ruby platform 区分正确 |
| 预发布 Gem | 两种客户端 | 本地 | 版本解析与索引正确 |
| 撤回 | `gem yank`＋Bundler | 本地 | 新解析不可见，已下载锁文件策略明确 |
| 恶意包 | 原生 API | 本地 | 不崩溃、不越界写文件、不泄露密钥 |

测试使用本地可控 HTTP 上游和可重建 fixtures；公共 rubygems.org 只做可选的端到端 smoke test，不能让 CI 依赖外网稳定。

## 7. 非兼容声明

- 不读取 Gemstash SQLite 数据库或其 YAML 对象目录；
- 不保证 Gemstash 的全部配置键、日志文本、管理命令或内部 API；
- 不保证老版本 Bundler/RubyGems 全兼容，支持版本由 CI 矩阵固定；
- 不支持合并公共与私有索引来隐藏来源；
- 不承诺完全复制 Gemstash 的缓存过期或异常行为。
