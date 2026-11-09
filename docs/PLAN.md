# Gemvault 实施计划

- 状态：已批准开始项目骨架；Registry 功能尚未实施
- 日期：2026-11-10
- 目标：交付可验证的 Crystal RubyGems 缓存代理与私有 Registry

## 1. 验收原则

每个阶段必须满足：

1. 协议、异常和安全边界有自动化测试；
2. 使用真实 RubyGems/Bundler 客户端，而不只使用 curl；
3. 文档状态与实际代码同步；
4. 不为了通过测试而缓存错误响应、跳过认证或关闭校验；
5. 性能声明必须附工作负载、环境和原始结果。

## 2. 阶段 0：工程与协议基线

目标：形成可重复开发、测试和审查的骨架。

### 任务

- [x] 初始化 Crystal 项目、MIT 许可证和基础文档；
- [ ] 建立 Linux CI：format、spec、build（依赖引入后增加依赖审计）；
- [ ] 配置 `Config`：默认值、YAML/环境变量、启动校验、敏感值脱敏；
- [ ] 建立显式 Router、统一错误响应、request ID 和访问日志；
- [ ] 实现 `/health/live` 与 `/health/ready`；
- [ ] 建立 fixtures 生成器：普通、平台、预发布、有依赖和损坏 Gem；
- [ ] 编写测试上游：可设置延迟、状态码、断流、ETag、Range 和 Digest；
- [ ] 固定 Bundler/RubyGems 支持矩阵与 contract test runner。

### 完成条件

CI 能构建 Linux 二进制并执行单元测试；真实客户端测试可以在失败时显示脱敏日志。健康检查不被实现成 Registry 可用性的虚假证明。

## 3. 阶段 1：公共源只读 MVP

目标：Bundler 可通过 Gemvault 完成公共 Gem 的缓存安装。

### 3.1 上游客户端与文件缓存

- [ ] 默认上游 URI allowlist、HTTPS、超时、有限重定向；
- [ ] 严格 Gem 名称/文件名解析与存储键映射；
- [ ] 对象存储接口、临时文件、原子 rename、SHA-256；
- [ ] 下载流式返回和 HEAD；
- [ ] 按资源 single-flight＋全局回源并发上限；
- [ ] 断流、磁盘满、客户端取消、上游 404/429/5xx 清理；
- [ ] 记录 cache hit/miss/wait、上游状态和字节数。

### 3.2 Compact Index 代理

- [ ] `/versions`、`/info/:name` 的状态和 Header 白名单透传；
- [ ] Range/If-Range/If-None-Match、200/206/304/416；
- [ ] Repr-Digest 完整表示校验；
- [ ] 上游 gzip/Vary/Content-Length 一致性；
- [ ] 缓存快照与 stale-if-error 仅在完整验证后启用；
- [ ] 防止不完整响应进入缓存。

### 验证

- [ ] 测试 fixture 的冷缓存 `bundle install`；
- [ ] 第二次安装不重复拉取 `.gem`；
- [ ] 上游更新索引后 Range 拼接和 SHA-256 正确；
- [ ] 断流/伪造 digest 后客户端可重试，缓存未污染；
- [ ] 20 个并发客户端请求相同冷 Gem 时只有一次上游 Gem 请求；
- [ ] 可选 rubygems.org smoke test，不作为 CI 必需条件。

## 4. 阶段 2：私有 Registry MVP

目标：使用标准 `gem push` 发布私有 Gem，并通过 Bundler/RubyGems 安装。

### 4.1 Gem 包与元数据

- [ ] 有界 tar/gzip 读取，禁止无关文件解压；
- [ ] Ruby Marshal 有界读取器及规范化 Specification；
- [ ] 名称、版本、平台、依赖、required Ruby/RubyGems 校验；
- [ ] fixtures 跨 Ruby/RubyGems 版本对照测试；
- [ ] fuzz：递归引用、超长容器、非法 UTF-8、未知类型、压缩炸弹。

### 4.2 存储与发布

- [ ] SQLite 迁移、WAL、busy timeout、唯一约束；
- [ ] 发布事务、对象提交顺序和启动恢复；
- [ ] `POST /private/api/v1/gems`；
- [ ] 私有 `/gems/:id` 流式读取；
- [ ] 同版本冲突和并发发布测试；
- [ ] 私有 Compact Index 快照生成、摘要和原子替换。

### 4.3 认证

- [ ] 本地 CLI 创建/撤销/轮换 API Key；
- [ ] Argon2id 或有依据的慢哈希实现；
- [ ] `fetch`/`push` 权限与 Authorization/Basic 两种客户端形式；
- [ ] 私有读取默认强制认证；
- [ ] 审计日志和全链路凭据脱敏。

### 验证

- [ ] `gem push pkg/example-0.1.0.gem --host .../private`；
- [ ] `gem install example --source .../private`；
- [ ] Gemfile 独立 `source ".../private"` block 的 `bundle install`；
- [ ] 缺 Key、错权限、撤销 Key 均失败，公共源不受影响；
- [ ] ruby 与原生平台 Gem 正确解析；
- [ ] 模拟崩溃后不会返回半个 Gem 或半个索引。

## 5. 阶段 3：撤回与旧客户端兼容

- [ ] `DELETE /private/api/v1/gems/yank` 和 `yank` 权限；
- [ ] yanked 版本索引移除、下载策略和禁止重新发布；
- [ ] 私有 Legacy Marshal 索引和 `.gemspec.rz`；
- [ ] 公共 Legacy specs/quick 端点代理；
- [ ] 根据实际支持矩阵测试旧版 RubyGems/Bundler；
- [ ] 明确 Dependency API 不支持或提供本地生成实现。

完成条件：兼容性矩阵中的 P1 项有真实客户端结果，不支持的接口返回明确错误。

## 6. 阶段 4：性能、安全与发布准备

### 性能

- [ ] 基准数据集：小 Gem、大 Gem、宽依赖项目、多个私有 Gem；
- [ ] 冷/热缓存、16/64/256 并发、索引 revalidation；
- [ ] 测量吞吐、P50/P95/P99、RSS、CPU、磁盘与上游请求数；
- [ ] 与同环境 Gemstash 对比，公开脚本、配置和原始结果；
- [ ] 根据 profile 决定线程、连接池和缓存参数，不预设胜出结论。

### 安全与运维

- [ ] 上游 SSRF、重定向凭据、路径穿越和反向代理信任测试；
- [ ] 上传/索引/Header/并发限制；
- [ ] 第三方依赖与许可证扫描；
- [ ] 备份、恢复、损坏 DB/对象和只读文件系统演练；
- [ ] systemd 与非 root container 示例；
- [ ] 优雅停止：停止接收、等待有界时间、清理临时文件；
- [ ] 发布前威胁建模和独立代码审查。

### 发布门槛

- [ ] 文档只列出真实实现功能；
- [ ] Linux x86_64 从干净环境部署成功；
- [ ] 数据备份并恢复后真实客户端安装成功；
- [ ] 所有 MVP 和 P1 contract tests 通过；
- [ ] 无已知高危安全问题；
- [ ] 版本号、CHANGELOG、Git tag 和 release binary 可追溯。

## 7. 当前执行顺序

```text
工程基线
  → 公共 Gem 文件缓存
  → 公共 Compact Index 正确性
  → Gem Marshal 读取与私有元数据
  → 私有发布/读取/认证
  → 私有索引与撤回
  → Legacy 兼容
  → 压测、加固与发布
```

Gem Marshal 解析可以独立开发，但私有 Registry 不能跳过它或用未验证的 YAML 假设替代。

## 8. 风险与应对

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| Ruby Marshal 规范覆盖不足 | 合法 Gem 无法上传或索引错误 | 多版本 fixtures、受限解析、失败关闭、与 Ruby 对照 |
| Compact Index Range/Digest 偏差 | Bundler checksum mismatch | 公共索引保真代理、真实客户端测试、完整摘要验证 |
| 跨 DB/文件提交不完整 | 丢失 Gem 或错误索引 | 明确提交顺序、原子 rename、启动恢复和崩溃测试 |
| 冷缓存请求风暴 | 上游放大、延迟和失败 | single-flight、有界队列、重试预算、退避 |
| 任意上游/重定向 | SSRF、凭据泄露 | 固定 allowlist，不做 URL 开放代理 |
| 公共/私有同名 Gem | 依赖混淆 | 独立命名空间、source block 文档与客户端测试 |
| 流式缓存中断 | 缓存污染 | 临时文件、长度/摘要检查、失败清理 |
| 性能目标未经验证 | 错误替代 Gemstash | 同环境真实负载对比，公开负面结果 |

## 9. 后续可选项

- 服务端命名的多上游与离线模式；
- PostgreSQL、S3 兼容对象存储和多实例；
- Web 管理页面、组织成员和 SSO；
- Prometheus  exporter 与管理 API；
- Gemstash 只读导入工具，而非原地兼容；
- 镜像全量同步与保留策略。

这些扩展不能破坏首版的单实例一致性、来源隔离和最小权限原则。
