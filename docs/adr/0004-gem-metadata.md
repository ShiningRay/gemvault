# ADR 0004：原生有界 Ruby Marshal 解析，不依赖 Ruby sidecar

- 状态：Accepted
- 日期：2026-11-10

## 背景

Gem specification 和 Legacy gemspec 使用 Ruby Marshal。调用 Ruby 能减少格式实现工作，但会使服务运行、资源隔离和部署重新依赖 Ruby 生态。

## 决定

实现只覆盖 Gem 元数据所需的 Ruby Marshal 类型，并限制深度、对象数、字节数和容器大小。解析失败必须关闭发布，不允许猜测元数据。

`crystal-ruby-marshal` 仅作参考，不作为当前关键依赖；其实验状态和序列化支持需要另行验证。

## 后果

保留 Crystal 服务的独立部署，但增加格式实现与跨版本测试成本。必须用 Ruby/RubyGems 生成的 fixtures 和 fuzz 测试降低风险。

如果实践证明维护成本过高，可重新评估导入期 Ruby 工具，但不能隐式增加线上 Ruby 依赖。
