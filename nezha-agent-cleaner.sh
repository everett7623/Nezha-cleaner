#!/bin/bash

# 哪吒探针Agent彻底清理脚本
# Nezha Agent Complete Removal Script
# https://github.com/your-username/nezha-agent-cleaner

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印横幅
echo -e "${BLUE}=================================================================${NC}"
echo -e "${GREEN}           哪吒探针Agent彻底清理脚本 v1.0                      ${NC}"
echo -e "${GREEN}           Nezha Agent Complete Removal Tool                    ${NC}"
echo -e "${BLUE}=================================================================${NC}"

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}[错误] 此脚本必须以root权限运行！${NC}" 
   echo -e "${RED}[Error] This script must be run as root!${NC}" 
   exit 1
fi

echo -e "${YELLOW}[信息] 开始清理哪吒探针Agent...${NC}"
echo -e "${YELLOW}[INFO] Starting Nezha Agent cleanup...${NC}"

# 步骤1: 检查和显示系统中的nezha进程
echo -e "\n${BLUE}[步骤1] 检查哪吒探针进程...${NC}"
echo -e "${BLUE}[Step1] Checking Nezha Agent processes...${NC}"
ps_result=$(ps aux | grep -E "[n]ezha-agent")
if [ -n "$ps_result" ]; then
    echo -e "${YELLOW}发现哪吒探针进程:${NC}"
    echo -e "${YELLOW}Found Nezha Agent processes:${NC}"
    echo "$ps_result"
else
    echo -e "${GREEN}未发现哪吒探针进程${NC}"
    echo -e "${GREEN}No Nezha Agent processes found${NC}"
fi

# 步骤2: 检查定时任务
echo -e "\n${BLUE}[步骤2] 检查相关定时任务...${NC}"
echo -e "${BLUE}[Step2] Checking related cron jobs...${NC}"
cron_result=$(crontab -l 2>/dev/null | grep -E "nezha|agent" || echo "No crontab found")
if [ "$cron_result" != "No crontab found" ]; then
    echo -e "${YELLOW}发现相关定时任务:${NC}"
    echo -e "${YELLOW}Found related cron jobs:${NC}"
    echo "$cron_result"
    
    echo -e "${YELLOW}正在移除相关定时任务...${NC}"
    echo -e "${YELLOW}Removing related cron jobs...${NC}"
    crontab -l | grep -v -E "nezha|agent" | crontab -
    echo -e "${GREEN}定时任务清理完成${NC}"
    echo -e "${GREEN}Cron jobs cleaned${NC}"
else
    echo -e "${GREEN}未发现相关定时任务${NC}"
    echo -e "${GREEN}No related cron jobs found${NC}"
fi

# 步骤3: 停止并禁用所有nezha-agent服务
echo -e "\n${BLUE}[步骤3] 停止并禁用所有哪吒探针服务...${NC}"
echo -e "${BLUE}[Step3] Stopping and disabling all Nezha Agent services...${NC}"
nezha_services=$(systemctl list-units --type=service | grep -E "nezha|agent" | awk '{print $1}')
if [ -n "$nezha_services" ]; then
    echo -e "${YELLOW}发现以下哪吒探针服务:${NC}"
    echo -e "${YELLOW}Found the following Nezha Agent services:${NC}"
    echo "$nezha_services"
    
    for service in $nezha_services; do
        echo -e "${YELLOW}停止并禁用 $service...${NC}"
        echo -e "${YELLOW}Stopping and disabling $service...${NC}"
        systemctl stop "$service" 2>/dev/null
        systemctl disable "$service" 2>/dev/null
    done
    echo -e "${GREEN}所有服务已停止并禁用${NC}"
    echo -e "${GREEN}All services stopped and disabled${NC}"
else
    echo -e "${GREEN}未发现哪吒探针服务${NC}"
    echo -e "${GREEN}No Nezha Agent services found${NC}"
fi

# 步骤4: 杀死所有相关进程
echo -e "\n${BLUE}[步骤4] 强制终止所有哪吒探针进程...${NC}"
echo -e "${BLUE}[Step4] Forcefully terminating all Nezha Agent processes...${NC}"
if pgrep -f "nezha-agent" >/dev/null; then
    echo -e "${YELLOW}正在终止进程...${NC}"
    echo -e "${YELLOW}Terminating processes...${NC}"
    pkill -9 -f "nezha-agent"
    echo -e "${GREEN}进程已终止${NC}"
    echo -e "${GREEN}Processes terminated${NC}"
else
    echo -e "${GREEN}没有需要终止的进程${NC}"
    echo -e "${GREEN}No processes to terminate${NC}"
fi

# 步骤5: 删除所有服务文件
echo -e "\n${BLUE}[步骤5] 删除所有服务文件...${NC}"
echo -e "${BLUE}[Step5] Removing all service files...${NC}"
service_files=$(find /etc/systemd/system/ -name "*nezha*" -o -name "*agent*" 2>/dev/null)
if [ -n "$service_files" ]; then
    echo -e "${YELLOW}发现以下服务文件:${NC}"
    echo -e "${YELLOW}Found the following service files:${NC}"
    echo "$service_files"
    
    echo -e "${YELLOW}删除服务文件...${NC}"
    echo -e "${YELLOW}Removing service files...${NC}"
    find /etc/systemd/system/ -name "*nezha*" -o -name "*agent*" -exec rm -f {} \; 2>/dev/null
    echo -e "${GREEN}服务文件已删除${NC}"
    echo -e "${GREEN}Service files removed${NC}"
else
    echo -e "${GREEN}未发现服务文件${NC}"
    echo -e "${GREEN}No service files found${NC}"
fi

# 步骤6: 删除二进制文件和目录
echo -e "\n${BLUE}[步骤6] 删除二进制文件和目录...${NC}"
echo -e "${BLUE}[Step6] Removing binary files and directories...${NC}"
directories=(
    "/opt/nezha"
    "/opt/agent"
    "/usr/local/nezha"
    "/usr/local/agent"
)

binaries=(
    "/usr/local/bin/nezha-agent"
    "/usr/bin/nezha-agent"
    "/usr/sbin/nezha-agent"
    "/bin/nezha-agent"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${YELLOW}删除目录: $dir${NC}"
        echo -e "${YELLOW}Removing directory: $dir${NC}"
        rm -rf "$dir"
    fi
done

for bin in "${binaries[@]}"; do
    if [ -f "$bin" ]; then
        echo -e "${YELLOW}删除二进制文件: $bin${NC}"
        echo -e "${YELLOW}Removing binary file: $bin${NC}"
        rm -f "$bin"
    fi
done

# 步骤7: 查找和删除所有相关文件
echo -e "\n${BLUE}[步骤7] 查找并删除所有相关文件...${NC}"
echo -e "${BLUE}[Step7] Finding and removing all related files...${NC}"
echo -e "${YELLOW}正在搜索系统中的哪吒探针相关文件...${NC}"
echo -e "${YELLOW}Searching for Nezha Agent related files in the system...${NC}"

# 创建临时文件保存查找结果
temp_file=$(mktemp)

# 搜索常见位置
find /root /home /tmp /var/tmp /etc /usr/local -name "*nezha*" -o -name "*agent*" 2>/dev/null | grep -v -E "ssh|mail|package" > "$temp_file"

if [ -s "$temp_file" ]; then
    echo -e "${YELLOW}发现以下相关文件:${NC}"
    echo -e "${YELLOW}Found the following related files:${NC}"
    cat "$temp_file"
    
    echo -e "${YELLOW}是否删除这些文件? [y/N] ${NC}"
    echo -e "${YELLOW}Would you like to delete these files? [y/N] ${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        while IFS= read -r file; do
            echo -e "${YELLOW}删除: $file${NC}"
            echo -e "${YELLOW}Removing: $file${NC}"
            rm -rf "$file" 2>/dev/null
        done < "$temp_file"
        echo -e "${GREEN}文件已删除${NC}"
        echo -e "${GREEN}Files removed${NC}"
    else
        echo -e "${YELLOW}跳过删除文件${NC}"
        echo -e "${YELLOW}Skipping file removal${NC}"
    fi
else
    echo -e "${GREEN}未发现相关文件${NC}"
    echo -e "${GREEN}No related files found${NC}"
fi

# 删除临时文件
rm -f "$temp_file"

# 步骤8: 重新加载systemd
echo -e "\n${BLUE}[步骤8] 重新加载systemd配置...${NC}"
echo -e "${BLUE}[Step8] Reloading systemd configuration...${NC}"
systemctl daemon-reload
echo -e "${GREEN}systemd配置已重新加载${NC}"
echo -e "${GREEN}systemd configuration reloaded${NC}"

# 步骤9: 检查Docker容器
echo -e "\n${BLUE}[步骤9] 检查相关Docker容器...${NC}"
echo -e "${BLUE}[Step9] Checking related Docker containers...${NC}"
if command -v docker &> /dev/null; then
    nezha_containers=$(docker ps -a | grep -E "nezha|agent" || echo "No containers found")
    if [ "$nezha_containers" != "No containers found" ]; then
        echo -e "${YELLOW}发现以下相关Docker容器:${NC}"
        echo -e "${YELLOW}Found the following related Docker containers:${NC}"
        echo "$nezha_containers"
        
        echo -e "${YELLOW}是否停止并删除这些容器? [y/N] ${NC}"
        echo -e "${YELLOW}Would you like to stop and remove these containers? [y/N] ${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            container_ids=$(docker ps -a | grep -E "nezha|agent" | awk '{print $1}')
            for id in $container_ids; do
                echo -e "${YELLOW}停止并删除容器: $id${NC}"
                echo -e "${YELLOW}Stopping and removing container: $id${NC}"
                docker stop "$id" 2>/dev/null
                docker rm "$id" 2>/dev/null
            done
            echo -e "${GREEN}容器已清理${NC}"
            echo -e "${GREEN}Containers cleaned${NC}"
        else
            echo -e "${YELLOW}跳过容器清理${NC}"
            echo -e "${YELLOW}Skipping container cleanup${NC}"
        fi
    else
        echo -e "${GREEN}未发现相关Docker容器${NC}"
        echo -e "${GREEN}No related Docker containers found${NC}"
    fi
else
    echo -e "${YELLOW}Docker未安装，跳过检查${NC}"
    echo -e "${YELLOW}Docker not installed, skipping check${NC}"
fi

# 步骤10: 最终检查
echo -e "\n${BLUE}[步骤10] 最终检查...${NC}"
echo -e "${BLUE}[Step10] Final check...${NC}"

# 检查是否还有任何nezha进程
if pgrep -f "nezha-agent" >/dev/null; then
    echo -e "${RED}警告: 仍然检测到哪吒探针进程!${NC}"
    echo -e "${RED}Warning: Nezha Agent processes still detected!${NC}"
    ps aux | grep -E "[n]ezha-agent"
else
    echo -e "${GREEN}未检测到任何哪吒探针进程${NC}"
    echo -e "${GREEN}No Nezha Agent processes detected${NC}"
fi

# 检查是否还有任何服务
nezha_services_remaining=$(systemctl list-units --type=service | grep -E "nezha|agent" | awk '{print $1}')
if [ -n "$nezha_services_remaining" ]; then
    echo -e "${RED}警告: 仍然检测到哪吒探针服务!${NC}"
    echo -e "${RED}Warning: Nezha Agent services still detected!${NC}"
    echo "$nezha_services_remaining"
else
    echo -e "${GREEN}未检测到任何哪吒探针服务${NC}"
    echo -e "${GREEN}No Nezha Agent services detected${NC}"
fi

echo -e "\n${BLUE}=================================================================${NC}"
echo -e "${GREEN}           哪吒探针Agent清理完成!                               ${NC}"
echo -e "${GREEN}           Nezha Agent cleanup complete!                         ${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e "${YELLOW}如果您在清理后仍然遇到问题，可能需要考虑系统重启或进一步的检查。${NC}"
echo -e "${YELLOW}If you still encounter issues after cleanup, consider restarting your system or performing further checks.${NC}"
echo -e "\n${GREEN}感谢使用此脚本!${NC}"
echo -e "${GREEN}Thank you for using this script!${NC}"

exit 0
