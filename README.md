# Gemvault

[![CI](https://github.com/ShiningRay/gemvault/actions/workflows/ci.yml/badge.svg)](https://github.com/ShiningRay/gemvault/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**English:** Gemvault is a planned Crystal implementation of a RubyGems-compatible caching proxy and private gem registry. This repository currently contains architecture, protocol research, an implementation roadmap, and a compilable project skeleton—not a working registry.

Gemvault 是一个以 **Crystal** 编写的 RubyGems 缓存代理与私有 Registry 项目。目标是用清晰、可验证的协议实现替代自建 Gemstash 的常见使用场景，而不是逐行翻译 Ruby 代码。

> [!IMPORTANT]
> **当前状态：设计与项目骨架。** 尚不能作为 RubyGems 源使用，不能缓存 Gem，也不能发布私有 Gem。功能完成情况以 [路线图](docs/ROADMAP.md) 为准。

## 目标

- 公共源：缓存 `rubygems.org`，支持 Bundler 的 Compact Index 工作流；
- 私有源：支持 `gem push`、`gem install`、版本撤回和分权 API Key；
- 隔离：公共与私有命名空间隔离，不在解析时合并不同来源；
- 性能：流式传输、有界内存、共享回源、文件流式读取；
- 运维：配置校验、结构化日志、健康检查和可备份的数据布局；
- 正确性：用真实 Bundler/RubyGems 客户端验收，而不只验证 HTTP 状态码。

## 非目标

首个稳定版本**不包含**：

- 读取或原地迁移 Gemstash 数据目录、数据库；
- Ruby 运行时依赖或调用 Ruby 作为线上服务组件；
- 任意客户端指定 URL 的开放代理；
- Web 管理后台、多用户组织体系、SSO；
- 多地域分发、多实例共享存储和高可用保证。

“协议兼容”指客户端工作流兼容，不意味着完整复制 Gemstash 的所有历史接口或缺陷。

## 设计文档

- [架构方案](docs/ARCHITECTURE.md)：模块、数据流、存储、安全与性能设计；
- [协议兼容矩阵](docs/COMPATIBILITY.md)：接口范围、约束和验收方式；
- [实施计划](docs/PLAN.md)：阶段、任务、完成条件和验证计划；
- [路线图](docs/ROADMAP.md)：版本范围和当前状态；
- [架构决策记录](docs/adr/)：关键技术选择及原因。

## 当前项目骨架

要求 Crystal **1.22.1 或更新版本**。生产部署以 Linux x86_64 为首要目标。

```bash
shards install
crystal spec
crystal run src/cli.cr -- --help
crystal run src/cli.cr -- --check-config
```

当前代码只提供版本、配置入口检查和健康处理器骨架；**尚未启动 Registry 服务**。`--check-config` 目前只验证启动参数与默认数据目录，不代表生产配置已完整实现。

### 开发检查

```bash
crystal tool format --check src spec
crystal spec
shards build
```

## 拟定使用方式（尚未实现）

以下是目标交互，不是当前可用功能：

```bash
# 公共源作为 Bundler 镜像
bundle config set --global \
  mirror.https://rubygems.org \
  https://gems.example.com

# 私有 Gem 使用独立 source，不合并公共命名空间
```

```ruby
source "https://rubygems.org"

source "https://gems.example.com/private" do
  gem "my_internal_gem"
end
```

## 项目状态与贡献

项目目前适合讨论协议、架构和验收方案，不适合部署到生产环境。开始贡献前请先阅读 [贡献指南](CONTRIBUTING.md) 和实施计划，避免在协议决策尚未落实时重复实现。

安全报告请通过 GitHub Private Vulnerability Reporting 提交，详见 [安全政策](SECURITY.md)。

## 参考

- [Gemstash](https://github.com/rubygems/gemstash)
- [RubyGems Compact Index API](https://guides.rubygems.org/rubygems-org-compact-index-api/)
- [RubyGems API](https://guides.rubygems.org/rubygems-org-api/)
- [Run your own gem server](https://guides.rubygems.org/run-your-own-gem-server/)

本项目是独立实现，不是 Gemstash 官方项目，也不代表 RubyGems 官方提供兼容保证。

## 许可证

[MIT](LICENSE) © 2026 代码之力
