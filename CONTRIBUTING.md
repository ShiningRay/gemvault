# 贡献指南

感谢关注 Gemvault。项目目前处于协议设计和工程骨架阶段，暂不接受“已兼容 Gemstash”或未经基准验证的性能声明。

## 开发环境

- Crystal 1.22.1 或更新版本；
- 首要开发与部署目标为 Linux x86_64；
- 真实客户端验收另需 Ruby、RubyGems、Bundler，但线上服务不依赖 Ruby。

```bash
shards install
crystal tool format --check src spec
crystal spec
shards build
bin/gemvault --check-config
```

## 开始实现前

1. 阅读 `docs/ARCHITECTURE.md`、`docs/COMPATIBILITY.md` 和 `docs/PLAN.md`；
2. 对关键协议选择，新增或更新 ADR；
3. 在 issue 中说明工作流、协议约束和测试方式；
4. 将功能控制在可独立验收的小改动中，不顺带重构无关模块。

## 测试要求

- 公共与私有源必须分开测试；
- Compact Index 需覆盖 Range、ETag、Repr-Digest、错误与断流；
- 上传需覆盖包大小/解压限制、Marshal 异常和重复版本；
- 认证测试需证明错误权限不能访问，而不只验证正确 Key 成功；
- 不得把公共 rubygems.org 作为 CI 必需依赖；
- 不能把占位测试、HTTP 200 或进程启动宣称为 Registry 兼容。

## 安全要求

不得提交 API Key、Token、包含 userinfo 的源 URL 或真实凭据。不得在日志中记录 Authorization。新增上游访问必须遵守 allowlist、重定向和超时约束。

疑似安全漏洞请遵循 `SECURITY.md`，不要提交公开 issue 披露可利用细节。

## 提交与 Pull Request

- 只包含本任务相关文件；
- 在 PR 中列出实际执行的命令和结果；
- 如果测试未运行或受环境限制，明确说明；
- 完成功能时同步更新 README 状态、兼容矩阵和路线图。
