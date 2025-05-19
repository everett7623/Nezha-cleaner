# 哪吒探针Agent彻底清理工具 (Nezha Agent Complete Removal Tool)

![GitHub License](https://img.shields.io/github/license/everett7623/Nezha-cleaner)
![Gitea Stars](https://img.shields.io/gitea/stars/everett7623/Nezha-cleaner)
![Gitea Forks](https://img.shields.io/gitea/forks/everett7623/Nezha-cleaner)

<p align="center">
    <img src="https://img.shields.io/badge/Language-Bash-blue?style=for-the-badge&logo=gnubash" alt="Language">
    <img src="https://img.shields.io/badge/Platform-Linux-orange?style=for-the-badge&logo=linux" alt="Platform">
</p>

这是一个专门用于彻底清理哪吒探针Agent被控端的工具。当你在管理界面删除Agent后它仍然会重新出现时，这个脚本可以帮助你完全清除系统中的所有相关组件和痕迹。

This is a specialized tool for completely removing Nezha Agent from your system. When you delete the Agent from the management interface but it still reappears, this script will help you thoroughly clean up all related components and traces in your system.

## 💡 特点 (Features)

- 🌐 **双语支持** - 同时显示中文和英文提示信息
- 🧹 **彻底清理** - 执行多个步骤全面清理哪吒探针的一切痕迹
- 🔄 **交互式操作** - 对于重要操作会请求用户确认
- 🎨 **彩色输出** - 使用不同颜色区分信息类型，提高可读性
- 🔍 **自动检测** - 智能检测各种可能的安装位置和启动方式
- 🐳 **Docker支持** - 检测并提供清理相关Docker容器的选项
- ✅ **最终验证** - 完成后进行最终检查确保彻底清理

## 🚀 一键运行 (One-click Execution)

```bash
bash <(curl -s https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh)
```

或者 (or)
```bash
bash <(wget -qO- https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh)

```

或者 (or)

```bash
wget -O nezha-agent-cleaner.sh https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh
chmod +x nezha-agent-cleaner.sh
sudo ./nezha-agent-cleaner.sh
```

## 📋 清理步骤 (Cleaning Steps)

脚本将执行以下步骤来彻底清理哪吒探针Agent：
The script will perform the following steps to thoroughly clean up the Nezha Agent:

1. **检查进程** - 识别所有正在运行的哪吒探针进程
2. **检查定时任务** - 查找并删除相关的crontab条目
3. **停止服务** - 停止并禁用所有哪吒探针相关的systemd服务
4. **终止进程** - 强制终止所有相关进程
5. **删除服务文件** - 清理系统中的所有服务配置文件
6. **删除二进制文件** - 移除所有执行文件和安装目录
7. **查找相关文件** - 全面扫描并删除所有相关文件
8. **重载系统配置** - 刷新systemd配置
9. **检查Docker容器** - 识别并提供清理相关Docker容器的选项
10. **最终验证** - 确认所有内容已被清理

## 📷 效果展示 (Screenshots)
![2025-05-19_105200](https://github.com/user-attachments/assets/8a649890-bdaa-4a41-a38f-b304053c67d7)

## ⚠️ 注意事项 (Notes)

- 此脚本需要root权限才能运行
- 使用前请确保备份任何重要数据
- 脚本有交互式步骤，可能需要人工确认某些操作
- 如果清理后问题仍然存在，可能需要重启系统

## 🔄 更新日志 (Changelog)

- **v1.0** (2025-05-19) - 初始版本发布

## 📜 开源许可 (License)

此项目采用 [MIT License](LICENSE) 开源许可协议。

## 🤝 贡献 (Contributing)

欢迎提交问题报告和功能请求！如果您想贡献代码，请随时提交拉取请求。

Feel free to submit issue reports and feature requests! If you want to contribute code, please submit pull requests at any time.

## 🌟 支持项目 (Support the Project)

如果您觉得这个项目有用，请考虑给它一个星标 ⭐ 
If you find this project useful, please consider giving it a star ⭐
