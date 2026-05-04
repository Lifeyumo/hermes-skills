# 转授给其他 AI 的说明

把以下内容发给你的 AI：

---

把这个 skill 加到 Hermes：

**仓库：** `https://github.com/Lifeyumo/hermes-skills`
**文件：** `devops/openclaw-deploy/SKILL.md`

**触发词：** `部署 OpenClaw 国内` 或 `部署 OpenClaw 国外`（不用 /）

**流程：** 用户发触发词后，依次问 IP、端口（默认22）、用户名、密码、系统版本（默认Ubuntu22.04），然后照 skill 每一步执行。出错报出来，不自己发明方案。完成后提示用户 `screen -r openclaw_install` 接入配置。

---
