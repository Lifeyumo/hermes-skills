---
name: deepseek-tool-calls-error
date: 2026-05-04
status: workaround
tags: [deepseek, model-bug, tool-calls, 400-error]
---

## 问题描述

**环境**：AAOOAAOOAA 服务器（175.178.122.111），Hermes Gateway + QQBot

**触发条件**：使用 DeepSeek-V4-Flash 模型，Agent 生成 tool_calls 调用工具后，模型未等待工具响应就返回了最终答案。

**错误信息**：
```
Non-retryable error (HTTP 400):
An assistant message with 'tool_calls' must be followed by tool messages
responding to each 'tool_call_id'. (insufficient tool messages following tool_calls message)
```

**影响**：QQ 交互完全失效，每次对话都报 400 错误。

---

## 原因分析

DeepSeek-V4-Flash 模型在回复中包含 `tool_calls`（函数调用指令），但模型在生成 tool_calls 后没有等待 Agent 执行工具并返回结果，就直接生成了最终文本回复。

这导致消息序列中出现了不完整的多轮对话——assistant 消息携带 tool_calls，但没有对应的 tool 消息跟随，DeepSeek API 判定为非法请求格式。

**根因**：模型侧的 tool_calls 实现与 OpenAI 协议不完全兼容，或模型在特定 prompt 长度/上下文下错误地提前结束了多轮工具调用链。

---

## 解决方案

### 临时方案（已执行）

在 AAOOAAOOAA 服务器上执行：
```bash
# 杀掉旧网关进程
pkill -f 'hermes gateway'
# 重启网关（新 session，干净的上下文）
nohup ~/.hermes/venv/bin/hermes gateway > ~/.hermes/logs/gateway.log 2>&1 &
```

重启后 Gateway 开启新 session，错误消失。但本质问题未解决，再次出现需重启。

### 永久方案（待验证）

1. **换模型**：使用兼容 tool_calls 的模型（如 Claude、GPT-4）
2. **等官方修复**：DeepSeek 修复 V4-Flash 的 tool_calls 问题后升级
3. **降级模型**：换用 DeepSeek-V2 或 V3 稳定版

---

## 变更记录

| 日期 | 添加者 | 变更内容 |
|------|--------|---------|
| 2026-05-04 | 小砚 | 初始记录：DeepSeek-V4-Flash tool_calls 错误及临时解决方案 |
