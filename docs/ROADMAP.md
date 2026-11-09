# 路线图

## 当前：0.1.0-dev — 设计与骨架

- [x] 明确公共缓存与私有 Registry 的目标边界；
- [x] 调研 Gemstash 与 RubyGems Compact Index；
- [x] 记录架构、协议兼容矩阵和实施计划；
- [x] Crystal 项目骨架与基础测试；
- [ ] 可启动的配置、路由和健康检查服务；
- [ ] 可重复的真实客户端测试环境。

**当前不可用作 Gem 源。**

## 0.2.0 — 公共缓存 MVP

- 公共 Gem 文件按需回源、流式缓存和并发去重；
- Compact Index 代理、Range/ETag/Repr-Digest；
- Bundler 冷缓存和热缓存安装；
- 失败处理、日志和基础健康检查。

## 0.3.0 — 私有 Registry MVP

- Ruby Marshal Gem 元数据读取；
- `gem push`、私有下载、Compact Index；
- 分权 API Key 和默认私有读取认证；
- SQLite 元数据、原子发布和崩溃恢复。

## 0.4.0 — 兼容完善

- `gem yank` 与不可变版本策略；
- Legacy specs 和 `.gemspec.rz`；
- 明确的 Bundler/RubyGems 支持矩阵；
- 完整错误契约。

## 0.5.0 — 生产候选

- 冷/热缓存和并发压测报告；
- 威胁建模、安全测试和备份恢复；
- Linux 部署示例、优雅停止和可观测性；
- 文档、升级和发布流程。

## 1.0.0 — 稳定版本

只有实施计划中的发布门槛全部满足后才能发布。版本日期与性能结论目前不作预设。

## 1.x 及以后候选

多上游 allowlist、离线模式、外部数据库、对象存储、管理 UI、多实例和 Gemstash 导入工具。尚未承诺这些功能。
