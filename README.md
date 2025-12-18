# 哪吒探针Agent彻底清理工具 (Nezha Agent Complete Removal Tool)
![GitHub License](https://img.shields.io/github/license/everett7623/Nezha-cleaner)
![GitHub Stars](https://img.shields.io/github/stars/everett7623/Nezha-cleaner)
![GitHub Forks](https://img.shields.io/github/forks/everett7623/Nezha-cleaner)

<p align="center">
    <img src="https://img.shields.io/badge/Language-Bash-blue?style=for-the-badge&logo=gnubash" alt="Language">
    <img src="https://img.shields.io/badge/Platform-Linux-orange?style=for-the-badge&logo=linux" alt="Platform">
    <img src="https://img.shields.io/badge/Version-1.1-green?style=for-the-badge" alt="Version">
</p>

这是一个专门用于彻底清理哪吒探针Agent被控端的安全工具。当你在管理界面删除Agent后它仍然会重新出现时，这个脚本可以帮助你完全清除系统中的所有相关组件和痕迹。

*This is a specialized and safe tool for completely removing Nezha Agent from your system. When you delete the Agent from the management interface but it still reappears, this script will help you thoroughly clean up all related components and traces.*

---

## 🔥 重要更新 (Important Update)

### ⚠️ v1.1 安全补丁 (Security Patch)

**修复了 v1.0 中的严重安全漏洞！** 旧版本可能会误删系统关键文件（如 ssh-agent、1Panel 等）。

**Fixed critical security vulnerability in v1.0!** The old version could accidentally delete system files (ssh-agent, 1Panel, etc.).

**更新内容 (What's Fixed):**
- ✅ 修复步骤7文件搜索过于宽泛的问题（从 `*agent*` 改为 `*nezha*`）
- ✅ 优化所有匹配模式，只精确识别哪吒探针相关文件
- ✅ 添加二次确认机制，防止误删
- ✅ 移除危险的通用目录（如 `/opt/agent`）

**强烈建议升级到 v1.1！** | **Strongly recommend upgrading to v1.1!**

---

## 💡 特点 (Features)

- 🛡️ **安全可靠** - v1.1 修复了所有已知的误删风险，只删除哪吒探针相关文件
- 🌐 **双语支持** - 同时显示中文和英文提示信息
- 🧹 **彻底清理** - 执行10个步骤全面清理哪吒探针的一切痕迹
- 🔄 **交互式操作** - 对于重要操作会请求用户确认
- 🎨 **彩色输出** - 使用不同颜色区分信息类型，提高可读性
- 🔍 **智能检测** - 自动检测各种可能的安装位置和启动方式
- 🐳 **Docker支持** - 检测并提供清理相关Docker容器的选项
- ✅ **最终验证** - 完成后进行最终检查确保彻底清理
- 🔒 **精确匹配** - 使用严格的模式匹配，避免影响其他软件

---

## 🚀 一键运行 (One-click Execution)

### 方式1: 使用 curl
```bash
bash <(curl -s https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh)
```

### 方式2: 使用 wget
```bash
bash <(wget -qO- https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh)
```

### 方式3: 下载后执行
```bash
wget -O nezha-agent-cleaner.sh https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh
chmod +x nezha-agent-cleaner.sh
sudo ./nezha-agent-cleaner.sh
```

---

## 📋 清理步骤 (Cleaning Steps)

脚本将执行以下步骤来彻底清理哪吒探针Agent：

*The script will perform the following steps to thoroughly clean up the Nezha Agent:*

| 步骤 | 说明 | Step | Description |
|------|------|------|-------------|
| 1️⃣ | 检查进程 | Check Processes | Identify all running Nezha Agent processes |
| 2️⃣ | 检查定时任务 | Check Cron Jobs | Find and remove related crontab entries |
| 3️⃣ | 停止服务 | Stop Services | Stop and disable all Nezha-related systemd services |
| 4️⃣ | 终止进程 | Kill Processes | Forcefully terminate all related processes |
| 5️⃣ | 删除服务文件 | Remove Service Files | Clean up all service configuration files |
| 6️⃣ | 删除二进制文件 | Remove Binaries | Remove all executable files and installation directories |
| 7️⃣ | 查找相关文件 | Find Related Files | Comprehensive scan and removal of all related files |
| 8️⃣ | 重载系统配置 | Reload systemd | Refresh systemd configuration |
| 9️⃣ | 检查Docker容器 | Check Docker | Identify and offer to clean related Docker containers |
| 🔟 | 最终验证 | Final Verification | Confirm everything has been cleaned |

---

## 📷 效果展示 (Screenshots)

![nezha-agent-cleanup-capture](https://img1.pixhost.to/images/10969/671885746_nezha-agent-cleanup-capture.png)

---

## ⚠️ 注意事项 (Important Notes)

### 使用前 (Before Use)
- ✅ 此脚本**必须**以 root 权限运行
- ✅ 使用前请确保备份任何重要数据
- ✅ 建议先在测试环境中运行

### 使用中 (During Use)
- 🔔 脚本有交互式步骤，需要人工确认某些操作
- 🔔 步骤7会列出所有包含"nezha"的文件，请仔细检查后再确认删除
- 🔔 步骤9会检测Docker容器，根据需要选择是否删除

### 使用后 (After Use)
- 🔄 如果清理后问题仍然存在，建议重启系统
- 🔄 可运行脚本中的"最终检查"部分确认清理效果

---

## 🛡️ 安全保证 (Safety Guarantees)

### v1.1 不会删除以下文件 (v1.1 Will NOT Delete)

- ✅ `ssh-agent` - SSH密钥代理
- ✅ `1panel-agent` - 1Panel管理面板
- ✅ `tailscale-agent` - Tailscale VPN客户端
- ✅ `packagekit` - 系统包管理工具
- ✅ `mail-agent` - 邮件代理
- ✅ 任何其他不包含"nezha"的agent软件

### 精确匹配规则 (Precise Matching Rules)

脚本使用以下严格的匹配模式：
- 进程：`nezha-agent`
- 服务：`nezha-agent.service` 或 `nezha.service`
- 文件：文件名必须包含 `nezha`
- Cron任务：`nezha-agent` 或 `/nezha/`
- Docker：镜像名包含 `nezha-agent` 或 `nezha:`

---

## 🔄 版本历史 (Version History)

### v1.1 (2025-12-18) - 🔒 安全更新
- 🐛 **修复严重bug**: 步骤7文件搜索从 `*agent*` 改为 `*nezha*`
- ✅ 优化所有grep/find命令的匹配模式
- ✅ 移除危险的通用目录（`/opt/agent`, `/usr/local/agent`）
- ✅ 添加二次确认机制
- ✅ 改进Docker容器识别逻辑
- 📝 更新文档，添加安全说明

### v1.0 (2025-05-19) - 初始版本
- 🎉 首次发布
- ⚠️ 已知问题：步骤7可能误删其他agent软件（已在v1.1修复）

---

## 🆚 版本对比 (Version Comparison)

| 功能 | v1.0 | v1.1 |
|------|------|------|
| 基础清理功能 | ✅ | ✅ |
| 精确匹配nezha文件 | ⚠️ 部分 | ✅ 完全 |
| 避免误删系统文件 | ❌ 有风险 | ✅ 安全 |
| 二次确认机制 | ❌ | ✅ |
| Docker容器精确识别 | ⚠️ 宽泛 | ✅ 精确 |
| 推荐使用 | ❌ | ✅ |

---

## 📜 开源许可 (License)

此项目采用 [MIT License](LICENSE) 开源许可协议。

*This project is licensed under the [MIT License](LICENSE).*

---

## 🤝 贡献 (Contributing)

欢迎提交问题报告和功能请求！如果您想贡献代码，请随时提交拉取请求。

*Feel free to submit issue reports and feature requests! If you want to contribute code, please submit pull requests at any time.*

### 如何贡献 (How to Contribute)
1. Fork 本项目
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

---

## 🐛 问题反馈 (Issue Reporting)

如果您遇到问题，请通过 [GitHub Issues](https://github.com/everett7623/Nezha-cleaner/issues) 反馈，提供以下信息：

*If you encounter any issues, please report them via [GitHub Issues](https://github.com/everett7623/Nezha-cleaner/issues) with the following information:*

- 操作系统版本 (OS version)
- 脚本版本 (Script version)
- 错误信息截图或日志 (Error screenshots or logs)
- 复现步骤 (Steps to reproduce)

---

## 💬 常见问题 (FAQ)

<details>
<summary><b>Q: 为什么需要root权限？</b></summary>

A: 因为需要操作systemd服务、删除系统目录和终止进程，这些操作都需要管理员权限。
</details>

<details>
<summary><b>Q: 会影响其他软件吗？</b></summary>

A: v1.1版本已修复所有已知的误删问题，只会删除包含"nezha"的文件，不会影响其他软件。
</details>

<details>
<summary><b>Q: 清理后如何确认？</b></summary>

A: 脚本结束时会进行最终检查，显示是否还有残留的进程或服务。您也可以重新运行脚本来验证。
</details>

<details>
<summary><b>Q: 支持哪些Linux发行版？</b></summary>

A: 支持所有使用systemd的Linux发行版，包括Ubuntu、Debian、CentOS、Fedora、Arch Linux等。
</details>

---

## 🌟 支持项目 (Support the Project)

如果您觉得这个项目有用，请考虑：

*If you find this project useful, please consider:*

- ⭐ 给项目一个星标 (Give it a star)
- 🔀 Fork 并分享给其他人 (Fork and share with others)
- 💬 在社区中推荐 (Recommend in your community)
- 🐛 提交问题和建议 (Submit issues and suggestions)

---

## 📧 联系方式 (Contact)

- GitHub: [@everett7623](https://github.com/everett7623)
- Issues: [GitHub Issues](https://github.com/everett7623/Nezha-cleaner/issues)

---

<p align="center">
    <b>感谢使用哪吒探针Agent清理工具！</b><br>
    <i>Thank you for using Nezha Agent Cleaner!</i>
</p>

<p align="center">
    Made with ❤️ by <a href="https://github.com/everett7623">everett7623</a>
</p>

## 🌟 支持项目 (Support the Project)

如果您觉得这个项目有用，请考虑给它一个星标 ⭐ 
If you find this project useful, please consider giving it a star ⭐
