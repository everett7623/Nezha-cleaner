#!/bin/bash

# ==============================================================================
#                          Nezha Agent Cleanup Tool
#
#      Project: https://github.com/everett7623/nezha-agent-cleaner
#      Author: everett7623
#      Version: 2.2 (Usage Counter + Bug Fixes)
#
#      Description: A safe utility to completely remove Nezha Agent and/or
#                   Dashboard with intelligent path tracking and Docker
#                   defense-in-depth. Supports three cleanup modes via
#                   interactive menu.
#
#      Changelog v2.2:
#      - Added: 使用统计计数器 — 主菜单显示累计运行次数 (visitor-badge.laobi.icu)
#      - Fixed: trap覆盖 — Both模式下临时文件不再泄漏 (全局数组追踪)
#      - Fixed: 符号链接保护 — safe_remove()检测指向保护目录的symlink
#      - Fixed: ExecStart前缀 — 扩展剥离字符类支持 ':' 修饰符
#      - Fixed: crontab边界 — 空crontab使用crontab -r, 无crontab命令时跳过
#      - Fixed: 竞态条件 — pgrep路径追踪增加/proc/$pid存在性检查
#      - Fixed: Docker匹配 — Agent模式grep收窄为nezha-agent, 不再误匹配Dashboard
#
#      Changelog v2.1:
#      - Fixed: safe_remove() now skips media/document files (png, jpg, pdf, md, etc.)
#               to prevent accidental deletion of user content like article images
#
#      Changelog v2.0:
#      - Added: Interactive menu — choose Agent, Dashboard, or Both cleanup
#      - Added: Dashboard (主控端) cleanup with 12-step safety pipeline
#      - Added: Docker image removal with separate user confirmation (Dashboard)
#      - Added: Container classification — Agent/Dashboard modes don't cross-target
#      - Changed: Agent cleanup extracted to function, Docker filter narrowed
#      - Security: All v1.4 safety patterns retained and extended to Dashboard
#
#      Changelog v1.4:
#      - Fixed: Step 7 find scan now excludes Docker/containerd internal storage
#      - Fixed: Step 9 Docker detection rewritten with native --filter + array + verification
#      - Fixed: Step 5 now uses safe_remove() for consistent safety discipline
#      - Security: Docker containers are verified individually before stop/rm
#
#      Changelog v1.3:
#      - Fixed: pkill no longer matches the script's own process
#      - Fixed: is_protected_dir now uses targeted leaf-dir protection
#      - Fixed: interactive prompts work when script is piped from curl
#      - Fixed: ExecStart prefix modifiers (-, @, +, !) correctly stripped
#      - Fixed: case-sensitivity consistency in file search and deletion
#      - Fixed: WorkingDirectory whitespace trimming
#      - Fixed: mktemp failure handling
#      - Added: safe_remove() helper for consistent safe deletion
#      - Added: SIGINT trap for temp file cleanup
#      - Added: /var/log and /var/lib to search roots
# ==============================================================================

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 使用统计全局变量
STATS_TOTAL=""

# 全局临时文件追踪数组 — 解决 Both 模式下 trap 覆盖导致临时文件泄漏的问题
_TEMP_FILES=()

# 注册临时文件到全局追踪数组
register_temp_file() {
    _TEMP_FILES+=("$1")
}

# 单一 EXIT trap — 清理所有注册的临时文件
trap 'for _f in "${_TEMP_FILES[@]}"; do rm -f "$_f"; done' EXIT

# ==============================================================================
#  使用统计获取 — visitor-badge.laobi.icu 集成
# ==============================================================================

# 函数: 获取使用统计数据（静默失败，不影响脚本功能）
fetch_usage_stats() {
    local hit_url="https://visitor-badge.laobi.icu/badge?page_id=everett7623.nezha-cleaner&left_text=runs"
    local response=""
    local timeout=3

    # HTTP 客户端选择: curl > wget > skip
    if command -v curl &>/dev/null; then
        response=$(curl -fsSL --max-time "$timeout" "$hit_url" 2>/dev/null) || return 1
    elif command -v wget &>/dev/null; then
        response=$(wget -qO- --timeout="$timeout" "$hit_url" 2>/dev/null) || return 1
    else
        return 1
    fi

    # 解析 SVG 中的计数文本
    # visitor-badge.laobi.icu SVG 中计数以纯数字形式出现在最后一个 <text> 节点
    local count_text
    count_text=$(echo "$response" | grep -oE '[0-9]+' | sort -n | tail -1)
    if [ -z "$count_text" ]; then
        return 1
    fi

    STATS_TOTAL="$count_text"

    # 验证结果是数字
    if ! [[ "$STATS_TOTAL" =~ ^[0-9]+$ ]]; then
        STATS_TOTAL=""
        return 1
    fi

    return 0
}

# 打印运行时的欢迎横幅
echo -e "${BLUE}=================================================================${NC}"
echo -e "${GREEN}     哪吒探针清理脚本 v2.2 (统计+修复)                         ${NC}"
echo -e "${GREEN}     Nezha Cleaner v2.2 (Usage Counter + Bug Fixes)            ${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e "${CYAN}v2.2: 启动菜单 — 可选卸载 Agent / Dashboard / 全部${NC}"
echo -e "${CYAN}v2.2: Menu-driven — Agent / Dashboard / Both cleanup modes${NC}"
echo -e "${BLUE}=================================================================${NC}"

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}[错误] 此脚本必须以root权限运行！${NC}"
   echo -e "${RED}[Error] This script must be run as root!${NC}"
   exit 1
fi

# 获取使用统计（静默，≤3秒超时）
fetch_usage_stats

# ==============================================================================
#  主菜单 — 选择清理模式
# ==============================================================================

echo -e "\n${BLUE}=================================================================${NC}"
echo -e "${GREEN}        请选择清理模式 / Please select cleanup mode:            ${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e ""
echo -e "${YELLOW}  1)${NC} ${GREEN}卸载 Agent (被控端)${NC} / Uninstall Agent"
echo -e "     → 清理被监控服务器上的哪吒探针Agent"
echo -e "     → Remove Nezha Agent from monitored servers"
echo -e ""
echo -e "${YELLOW}  2)${NC} ${GREEN}卸载 Dashboard (主控端)${NC} / Uninstall Dashboard"
echo -e "     → 清理哪吒探针监控面板及其数据（含Docker镜像）"
echo -e "     → Remove Nezha Dashboard, data files, and Docker images"
echo -e ""
echo -e "${YELLOW}  3)${NC} ${GREEN}同时卸载两者${NC} / Uninstall Both"
echo -e "     → 彻底清除哪吒探针的一切：Agent + Dashboard"
echo -e "     → Complete removal: Agent + Dashboard + Docker images"
echo -e ""
echo -e "${YELLOW}  4)${NC} ${GREEN}退出${NC} / Exit"
echo -e ""
if [ -n "$STATS_TOTAL" ]; then
    echo -e "${CYAN}  📊 累计运行: ${STATS_TOTAL} 次${NC}"
    echo -e ""
fi
echo -e "${BLUE}=================================================================${NC}"
echo -ne "${YELLOW}请输入选项 (1-4) / Enter your choice (1-4): ${NC}"
read -r CLEANUP_MODE </dev/tty

case "$CLEANUP_MODE" in
    1) TARGET="agent"
       echo -e "\n${GREEN}✓ 已选择: 卸载 Agent (被控端)${NC}"
       echo -e "${GREEN}✓ Selected: Uninstall Agent${NC}" ;;
    2) TARGET="dashboard"
       echo -e "\n${GREEN}✓ 已选择: 卸载 Dashboard (主控端)${NC}"
       echo -e "${GREEN}✓ Selected: Uninstall Dashboard${NC}" ;;
    3) TARGET="both"
       echo -e "\n${GREEN}✓ 已选择: 同时卸载两者${NC}"
       echo -e "${GREEN}✓ Selected: Uninstall Both${NC}" ;;
    4) echo -e "\n${GREEN}已退出 / Exited${NC}"; exit 0 ;;
    *) echo -e "\n${RED}[错误] 无效选择，请输入 1-4${NC}"
       echo -e "${RED}[Error] Invalid choice, please enter 1-4${NC}"
       exit 1 ;;
esac

# ==============================================================================
#  安全基础设施 — 保护目录 + 安全删除
# ==============================================================================

# 获取脚本自身的PID，防止 pgrep/pkill 误匹配自身（历史遗留：实际由 bracket trick 实现）
SCRIPT_PID=$$

# 定义系统保护目录列表 — 只保护关键系统叶子目录，不保护 /usr/local, /etc, /var 等安装区域
# 使用精准的叶子目录列表，而非上级目录前缀，避免误伤 /usr/local/nezha-agent 等合法清理目标
PROTECTED_DIRS=(
    "/bin"
    "/sbin"
    "/usr/bin"
    "/usr/sbin"
    "/usr/lib"
    "/usr/lib64"
    "/usr/libexec"
    "/usr/share"
    "/usr/include"
    "/usr/src"
    "/lib"
    "/lib64"
    "/boot"
    "/dev"
    "/proc"
    "/sys"
    "/run"
)

# 函数：检查路径是否为系统保护目录
is_protected_dir() {
    local path="$1"
    local real_path=$(realpath "$path" 2>/dev/null || readlink -f "$path" 2>/dev/null || echo "$path")

    for protected in "${PROTECTED_DIRS[@]}"; do
        if [[ "$real_path" == "$protected" ]] || [[ "$real_path" == "$protected"/* ]]; then
            return 0  # 是保护目录
        fi
    done
    return 1  # 不是保护目录
}

# 函数：安全删除 — 统一的删除包装，所有删除操作均通过此函数
# 参数: $1 = 路径, $2 = 描述(可选,用于日志)
safe_remove() {
    local target="$1"
    local desc="${2:-$target}"

    # 检查路径是否存在（TOCTOU 缓解: 先解析再检查）
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        return 0  # 已不存在，视为成功
    fi

    # 符号链接指向保护目录检查
    if [ -L "$target" ]; then
        local link_target
        link_target=$(readlink -f "$target" 2>/dev/null || readlink "$target" 2>/dev/null)
        if [ -n "$link_target" ] && is_protected_dir "$link_target"; then
            echo -e "${RED}⚠️  跳过指向保护目录的符号链接: $desc → $link_target${NC}"
            echo -e "${RED}⚠️  Skipping symlink pointing to protected directory: $desc → $link_target${NC}"
            return 1
        fi
    fi

    # 系统目录保护检查
    if is_protected_dir "$target"; then
        echo -e "${RED}⚠️  跳过系统保护路径: $desc${NC}"
        return 1
    fi

    # 名称安全检查: 路径必须包含 "nezha"（大小写不敏感）
    local target_lower="${target,,}"
    if [[ "$target_lower" != *"nezha"* ]]; then
        echo -e "${YELLOW}⚠️  路径不包含nezha，跳过: $desc${NC}"
        return 1
    fi

    # 文件类型安全检查: 跳过媒体/文档类文件（不可能是哪吒监控软件组件）
    # 哪吒监控组件只包含: 二进制文件(无扩展名)、.service、.json、.yaml、.sh 等
    # 以下文件类型是用户个人内容，即使文件名含"nezha"也应保护
    if [ -f "$target" ]; then
        case "$target_lower" in
            *.png|*.jpg|*.jpeg|*.gif|*.svg|*.webp|*.bmp|*.ico|*.heic|*.heif|\
            *.pdf|*.doc|*.docx|*.md|*.txt|*.rst|*.html|*.htm|*.rtf|\
            *.mp4|*.mp3|*.avi|*.mov|*.mkv|*.wav|*.flac|\
            *.pptx|*.ppt|*.xlsx|*.xls|*.csv)
                echo -e "${YELLOW}⚠️  跳过媒体/文档文件 (非哪吒监控组件): $desc${NC}"
                echo -e "${YELLOW}⚠️  Skipping media/document file (not a Nezha component): $desc${NC}"
                return 1
                ;;
        esac
    fi

    # 执行删除
    rm -rf "$target" 2>/dev/null
    local rc=$?
    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}✓ 已删除: $desc${NC}"
        return 0
    else
        echo -e "${RED}✗ 删除失败: $desc${NC}"
        return 1
    fi
}

# ==============================================================================
#  cleanup_agent() — 卸载哪吒探针 Agent (被控端)
#  沿用 v1.4 的 10 步流程，仅 Docker 过滤器收窄为 *nezha-agent*
# ==============================================================================
cleanup_agent() {
    echo -e "\n${BLUE}=================================================================${NC}"
    echo -e "${GREEN}        开始卸载哪吒探针 Agent (被控端)                         ${NC}"
    echo -e "${GREEN}        Starting Nezha Agent (Controlled Endpoint) cleanup      ${NC}"
    echo -e "${BLUE}=================================================================${NC}"

    local -a TRACKED_PATHS
    local -A unique_paths

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

    # 步骤1.5: 智能路径追踪 - 通过进程找到所有相关路径
    echo -e "\n${CYAN}[步骤1.5] 🔍 智能路径追踪...${NC}"
    echo -e "${CYAN}[Step1.5] 🔍 Intelligent path tracking...${NC}"

    # 通过进程追踪可执行文件路径
    if pgrep -f "[n]ezha-agent" >/dev/null; then
        echo -e "${YELLOW}正在追踪运行中的进程路径...${NC}"
        echo -e "${YELLOW}Tracking running process paths...${NC}"

        while IFS= read -r proc_path; do
            if [ -n "$proc_path" ] && [ -f "$proc_path" ]; then
                TRACKED_PATHS+=("$proc_path")
                parent_dir=$(dirname "$proc_path")

                if ! is_protected_dir "$parent_dir"; then
                    TRACKED_PATHS+=("$parent_dir")
                fi

                echo -e "${CYAN}  → 追踪到: $proc_path${NC}"
            fi
        done < <(pgrep -f "[n]ezha-agent" 2>/dev/null | while read -r _pid; do
            [ -d "/proc/$_pid" ] || continue
            readlink -f "/proc/$_pid/exe" 2>/dev/null
        done | sort -u)
    fi

    # 通过systemd服务追踪路径
    if systemctl list-units --type=service --all 2>/dev/null | grep -qiE "nezha-agent|nezha\.service"; then
        echo -e "${YELLOW}正在分析systemd服务配置...${NC}"
        echo -e "${YELLOW}Analyzing systemd service configs...${NC}"

        while IFS= read -r service_file; do
            if [ -f "$service_file" ]; then
                exec_start=$(grep -E "^ExecStart=" "$service_file" | sed 's/^ExecStart=[-@!+:]*//' | awk '{print $1}')
                if [ -n "$exec_start" ] && [ -f "$exec_start" ]; then
                    real_path=$(realpath "$exec_start" 2>/dev/null || readlink -f "$exec_start" 2>/dev/null)
                    if [ -n "$real_path" ]; then
                        TRACKED_PATHS+=("$real_path")
                        parent_dir=$(dirname "$real_path")
                        if ! is_protected_dir "$parent_dir"; then
                            TRACKED_PATHS+=("$parent_dir")
                        fi
                        echo -e "${CYAN}  → 从服务追踪到: $real_path${NC}"
                    fi
                fi

                working_dir=$(grep -E "^WorkingDirectory=" "$service_file" | sed 's/^WorkingDirectory=//' | xargs)
                if [ -n "$working_dir" ] && [ -d "$working_dir" ]; then
                    real_path=$(realpath "$working_dir" 2>/dev/null || readlink -f "$working_dir" 2>/dev/null)
                    if [ -n "$real_path" ] && ! is_protected_dir "$real_path"; then
                        TRACKED_PATHS+=("$real_path")
                        echo -e "${CYAN}  → 工作目录: $real_path${NC}"
                    fi
                fi
            fi
        done < <(find /etc/systemd/system/ -type f \( -name "*nezha-agent*" -o -name "*nezha.service*" \) 2>/dev/null)
    fi

    # 去重并显示所有追踪到的路径
    if [ ${#TRACKED_PATHS[@]} -gt 0 ]; then
        for path in "${TRACKED_PATHS[@]}"; do
            unique_paths["$path"]=1
        done

        echo -e "\n${GREEN}✓ 智能追踪发现以下安装路径:${NC}"
        echo -e "${GREEN}✓ Intelligent tracking found these installation paths:${NC}"
        for path in "${!unique_paths[@]}"; do
            if [ -e "$path" ]; then
                echo -e "${YELLOW}  📍 $path${NC}"
            fi
        done
    else
        echo -e "${GREEN}未通过进程追踪到特殊安装路径${NC}"
        echo -e "${GREEN}No special installation paths tracked from processes${NC}"
    fi

    # 步骤2: 检查定时任务（精确匹配nezha-agent）
    echo -e "\n${BLUE}[步骤2] 检查相关定时任务...${NC}"
    echo -e "${BLUE}[Step2] Checking related cron jobs...${NC}"
    if ! command -v crontab &>/dev/null; then
        echo -e "${GREEN}系统无 crontab 命令，跳过定时任务检查${NC}"
        echo -e "${GREEN}No crontab command available, skipping cron check${NC}"
    else
        cron_result=$(crontab -l 2>/dev/null | grep -iE "nezha-agent|/nezha/" || echo "No crontab found")
        if [ "$cron_result" != "No crontab found" ]; then
            echo -e "${YELLOW}发现相关定时任务:${NC}"
            echo -e "${YELLOW}Found related cron jobs:${NC}"
            echo "$cron_result"

            echo -e "${YELLOW}正在移除相关定时任务...${NC}"
            echo -e "${YELLOW}Removing related cron jobs...${NC}"
            local filtered
            filtered=$(crontab -l 2>/dev/null | grep -v -iE "nezha-agent|/nezha/")
            if [ -z "$filtered" ]; then
                crontab -r 2>/dev/null
            else
                echo "$filtered" | crontab -
            fi
            echo -e "${GREEN}定时任务清理完成${NC}"
            echo -e "${GREEN}Cron jobs cleaned${NC}"
        else
            echo -e "${GREEN}未发现相关定时任务${NC}"
            echo -e "${GREEN}No related cron jobs found${NC}"
        fi
    fi

    # 步骤3: 停止并禁用所有nezha-agent服务（精确匹配）
    echo -e "\n${BLUE}[步骤3] 停止并禁用所有哪吒探针服务...${NC}"
    echo -e "${BLUE}[Step3] Stopping and disabling all Nezha Agent services...${NC}"
    nezha_services=$(systemctl list-units --type=service --all 2>/dev/null | grep -iE "nezha-agent|nezha\.service" | awk '{print $1}')
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
    if pgrep -f "[n]ezha-agent" >/dev/null; then
        echo -e "${YELLOW}正在终止进程...${NC}"
        echo -e "${YELLOW}Terminating processes...${NC}"
        pkill -9 -f "[n]ezha-agent"
        sleep 1
        echo -e "${GREEN}进程已终止${NC}"
        echo -e "${GREEN}Processes terminated${NC}"
    else
        echo -e "${GREEN}没有需要终止的进程${NC}"
        echo -e "${GREEN}No processes to terminate${NC}"
    fi

    # 步骤5: 删除所有服务文件（精确匹配）
    echo -e "\n${BLUE}[步骤5] 删除所有服务文件...${NC}"
    echo -e "${BLUE}[Step5] Removing all service files...${NC}"
    service_files=$(find /etc/systemd/system/ -type f \( -name "*nezha-agent*" -o -name "*nezha.service*" \) 2>/dev/null)
    if [ -n "$service_files" ]; then
        echo -e "${YELLOW}发现以下服务文件:${NC}"
        echo -e "${YELLOW}Found the following service files:${NC}"
        echo "$service_files"

        echo -e "${YELLOW}删除服务文件...${NC}"
        echo -e "${YELLOW}Removing service files...${NC}"
        while IFS= read -r svc_file; do
            safe_remove "$svc_file" "$svc_file (systemd unit)"
        done <<< "$service_files"
        echo -e "${GREEN}服务文件已删除${NC}"
        echo -e "${GREEN}Service files removed${NC}"
    else
        echo -e "${GREEN}未发现服务文件${NC}"
        echo -e "${GREEN}No service files found${NC}"
    fi

    # 步骤6: 删除标准位置的二进制文件和目录
    echo -e "\n${BLUE}[步骤6] 删除标准位置的二进制文件和目录...${NC}"
    echo -e "${BLUE}[Step6] Removing binaries and directories in standard locations...${NC}"

    directories=(
        "/opt/nezha"
        "/opt/nezha-agent"
        "/usr/local/nezha"
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
            safe_remove "$dir" "$dir (standard install dir)"
        fi
    done

    for bin in "${binaries[@]}"; do
        if [ -f "$bin" ]; then
            echo -e "${YELLOW}删除二进制文件: $bin${NC}"
            echo -e "${YELLOW}Removing binary file: $bin${NC}"
            safe_remove "$bin" "$bin (standard binary)"
        fi
    done

    # 步骤6.5: 删除智能追踪到的非标准路径
    if [ ${#unique_paths[@]} -gt 0 ]; then
        echo -e "\n${CYAN}[步骤6.5] 🎯 清理智能追踪到的路径...${NC}"
        echo -e "${CYAN}[Step6.5] 🎯 Cleaning tracked paths...${NC}"

        for path in "${!unique_paths[@]}"; do
            if [ -e "$path" ] || [ -L "$path" ]; then
                safe_remove "$path"
            fi
        done
    fi

    # 步骤7: 查找和删除所有相关文件（全局搜索）
    echo -e "\n${BLUE}[步骤7] 查找并删除所有相关文件（全局搜索）...${NC}"
    echo -e "${BLUE}[Step7] Finding and removing all related files (global search)...${NC}"
    echo -e "${YELLOW}正在搜索系统中的哪吒探针相关文件...${NC}"
    echo -e "${YELLOW}Searching for Nezha Agent related files in the system...${NC}"
    echo -e "${CYAN}注意: 图片/文档/媒体文件将自动跳过（非哪吒监控组件）${NC}"
    echo -e "${CYAN}Note: Images/documents/media files will be auto-skipped (not Nezha components)${NC}"

    temp_file=$(mktemp) || {
        echo -e "${RED}[错误] 无法创建临时文件，请检查 /tmp 权限${NC}"
        echo -e "${RED}[Error] Failed to create temporary file, check /tmp permissions${NC}"
        exit 1
    }
    register_temp_file "$temp_file"

    find /root /home /tmp /var/tmp /var/log /var/lib /etc /usr/local /opt /data /www \
        \( -path /var/lib/docker -prune \) -o \
        \( -path /var/lib/containerd -prune \) -o \
        \( -iname "*nezha*" -print \) 2>/dev/null > "$temp_file"

    if [ -s "$temp_file" ]; then
        echo -e "${YELLOW}发现以下相关文件:${NC}"
        echo -e "${YELLOW}Found the following related files:${NC}"
        cat "$temp_file"

        echo -e "\n${YELLOW}是否删除这些文件? [y/N] ${NC}"
        echo -e "${YELLOW}Would you like to delete these files? [y/N] ${NC}"
        read -r response </dev/tty
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            while IFS= read -r file; do
                safe_remove "$file"
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

    # 步骤8: 重新加载systemd
    echo -e "\n${BLUE}[步骤8] 重新加载systemd配置...${NC}"
    echo -e "${BLUE}[Step8] Reloading systemd configuration...${NC}"
    systemctl daemon-reload 2>/dev/null
    echo -e "${GREEN}systemd配置已重新加载${NC}"
    echo -e "${GREEN}systemd configuration reloaded${NC}"

    # 步骤9: 检查Docker容器（Agent模式 — 只处理 Agent 容器）
    echo -e "\n${BLUE}[步骤9] 检查相关Docker容器...${NC}"
    echo -e "${BLUE}[Step9] Checking related Docker containers...${NC}"
    if command -v docker &> /dev/null; then
        declare -A nezha_container_map
        TAB_CHAR=$(printf '\t')

        # 方法1: Docker 原生过滤器 — 精确匹配 Agent 容器名
        while IFS="$TAB_CHAR" read -r cid cname cimage; do
            [[ -n "$cid" ]] && nezha_container_map["$cid"]="${cname}|${cimage}"
        done < <(docker ps -a --filter "name=*nezha-agent*" --format "{{.ID}}\t{{.Names}}\t{{.Image}}" 2>/dev/null)

        # 方法2: grep 补充匹配 — 镜像名含 nezha-agent 的容器
        while IFS="$TAB_CHAR" read -r cid cname cimage; do
            [[ -n "$cid" ]] && nezha_container_map["$cid"]="${cname}|${cimage}"
        done < <(docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Image}}" 2>/dev/null | grep -iE "nezha-agent")

        if [ ${#nezha_container_map[@]} -gt 0 ]; then
            echo -e "${YELLOW}发现以下相关Docker容器:${NC}"
            echo -e "${YELLOW}Found the following related Docker containers:${NC}"
            for cid in "${!nezha_container_map[@]}"; do
                IFS='|' read -r cname cimage <<< "${nezha_container_map[$cid]}"
                printf "  %s\t%s\t%s\n" "$cid" "$cname" "$cimage"
            done

            echo -e "${YELLOW}是否停止并删除这些容器? [y/N] ${NC}"
            echo -e "${YELLOW}Would you like to stop and remove these containers? [y/N] ${NC}"
            read -r response </dev/tty
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                for cid in "${!nezha_container_map[@]}"; do
                    IFS='|' read -r cname cimage <<< "${nezha_container_map[$cid]}"

                    verify_name=$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null | tr '[:upper:]' '[:lower:]')
                    verify_image=$(docker inspect --format '{{.Config.Image}}' "$cid" 2>/dev/null | tr '[:upper:]' '[:lower:]')

                    if [[ "$verify_name" == *nezha* ]] || [[ "$verify_image" == *nezha* ]]; then
                        echo -e "${YELLOW}停止并删除容器: $cid ($cname) [镜像: $cimage]${NC}"
                        echo -e "${YELLOW}Stopping and removing container: $cid ($cname) [Image: $cimage]${NC}"
                        docker stop "$cid" 2>/dev/null
                        docker rm "$cid" 2>/dev/null
                    else
                        echo -e "${RED}⚠️  容器 $cid ($cname) 未通过 nezha 验证，跳过删除${NC}"
                        echo -e "${RED}⚠️  Container $cid ($cname) failed nezha verification, skipping${NC}"
                    fi
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

    if pgrep -f "[n]ezha-agent" >/dev/null; then
        echo -e "${RED}⚠️  警告: 仍然检测到哪吒探针进程!${NC}"
        echo -e "${RED}⚠️  Warning: Nezha Agent processes still detected!${NC}"
        ps aux | grep -E "[n]ezha-agent"
    else
        echo -e "${GREEN}✓ 未检测到任何哪吒探针进程${NC}"
        echo -e "${GREEN}✓ No Nezha Agent processes detected${NC}"
    fi

    nezha_services_remaining=$(systemctl list-units --type=service --all 2>/dev/null | grep -iE "nezha-agent|nezha\.service" | awk '{print $1}')
    if [ -n "$nezha_services_remaining" ]; then
        echo -e "${RED}⚠️  警告: 仍然检测到哪吒探针服务!${NC}"
        echo -e "${RED}⚠️  Warning: Nezha Agent services still detected!${NC}"
        echo "$nezha_services_remaining"
    else
        echo -e "${GREEN}✓ 未检测到任何哪吒探针服务${NC}"
        echo -e "${GREEN}✓ No Nezha Agent services detected${NC}"
    fi

    remaining_files=$(find /root /home /opt /usr/local /data /www /var/log /var/lib 2>/dev/null | grep -i "nezha" | head -10)
    if [ -n "$remaining_files" ]; then
        echo -e "${YELLOW}⚠️  发现一些可能的残留文件:${NC}"
        echo -e "${YELLOW}⚠️  Found some possible remaining files:${NC}"
        echo "$remaining_files"
        echo -e "${YELLOW}如需手动清理，请检查这些文件${NC}"
        echo -e "${YELLOW}Please check these files for manual cleanup if needed${NC}"
    else
        echo -e "${GREEN}✓ 未发现任何残留文件${NC}"
        echo -e "${GREEN}✓ No remaining files detected${NC}"
    fi

    echo -e "\n${GREEN}✓ Agent (被控端) 清理完成!${NC}"
    echo -e "${GREEN}✓ Agent (Controlled Endpoint) cleanup complete!${NC}"
}

# ==============================================================================
#  cleanup_dashboard() — 卸载哪吒探针 Dashboard (主控端)
#  12步安全清理流程，4层Docker纵深防御
# ==============================================================================
cleanup_dashboard() {
    echo -e "\n${BLUE}=================================================================${NC}"
    echo -e "${GREEN}        开始卸载哪吒探针 Dashboard (主控端)                     ${NC}"
    echo -e "${GREEN}        Starting Nezha Dashboard (Control Panel) cleanup        ${NC}"
    echo -e "${BLUE}=================================================================${NC}"

    local -a TRACKED_PATHS
    local -A unique_paths

    # D1: 检查Dashboard进程（裸机 + Docker）
    echo -e "\n${BLUE}[步骤D1] 检查哪吒探针Dashboard进程...${NC}"
    echo -e "${BLUE}[Step D1] Checking Nezha Dashboard processes...${NC}"

    local found_dashboard=false

    # 检查裸机进程
    ps_result=$(ps aux | grep -E "[n]ezha-dashboard")
    if [ -n "$ps_result" ]; then
        found_dashboard=true
        echo -e "${YELLOW}发现Dashboard裸机进程:${NC}"
        echo -e "${YELLOW}Found Dashboard bare-metal processes:${NC}"
        echo "$ps_result"
    fi

    # 检查Dashboard Docker容器（排除 Agent 容器）
    if command -v docker &> /dev/null; then
        docker_ps=$(docker ps --filter "name=*nezha*" --format "{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null | grep -vi "nezha-agent")
        if [ -n "$docker_ps" ]; then
            found_dashboard=true
            echo -e "${YELLOW}发现Dashboard Docker容器:${NC}"
            echo -e "${YELLOW}Found Dashboard Docker containers:${NC}"
            echo "$docker_ps"
        fi
    fi

    if [ "$found_dashboard" = false ]; then
        echo -e "${GREEN}未发现Dashboard进程${NC}"
        echo -e "${GREEN}No Dashboard processes found${NC}"
    fi

    # D1也检查 nezha.service (非agent的通用nezha服务)
    if systemctl list-units --type=service --all 2>/dev/null | grep -qi "nezha-dashboard\|nezha\.service"; then
        echo -e "${YELLOW}发现Dashboard相关systemd服务:${NC}"
        systemctl list-units --type=service --all 2>/dev/null | grep -iE "nezha-dashboard|nezha\.service"
    fi

    # D2: 智能路径追踪 — Dashboard版本
    echo -e "\n${CYAN}[步骤D2] 🔍 智能路径追踪 (Dashboard)...${NC}"
    echo -e "${CYAN}[Step D2] 🔍 Intelligent path tracking (Dashboard)...${NC}"

    # 追踪Dashboard裸机进程
    if pgrep -f "[n]ezha-dashboard" >/dev/null; then
        echo -e "${YELLOW}正在追踪Dashboard进程路径...${NC}"
        echo -e "${YELLOW}Tracking Dashboard process paths...${NC}"

        while IFS= read -r proc_path; do
            if [ -n "$proc_path" ] && [ -f "$proc_path" ]; then
                TRACKED_PATHS+=("$proc_path")
                parent_dir=$(dirname "$proc_path")
                if ! is_protected_dir "$parent_dir"; then
                    TRACKED_PATHS+=("$parent_dir")
                fi
                echo -e "${CYAN}  → 追踪到: $proc_path${NC}"
            fi
        done < <(pgrep -f "[n]ezha-dashboard" 2>/dev/null | while read -r _pid; do
            [ -d "/proc/$_pid" ] || continue
            readlink -f "/proc/$_pid/exe" 2>/dev/null
        done | sort -u)
    fi

    # 追踪systemd服务中的Dashboard相关配置
    if systemctl list-units --type=service --all 2>/dev/null | grep -qiE "nezha-dashboard|nezha\.service"; then
        echo -e "${YELLOW}正在分析Dashboard systemd服务配置...${NC}"
        echo -e "${YELLOW}Analyzing Dashboard systemd service configs...${NC}"

        # Dashboard 专用匹配：*nezha-dashboard* 和 *nezha.service*（排除 *nezha-agent*）
        while IFS= read -r service_file; do
            if [ -f "$service_file" ]; then
                exec_start=$(grep -E "^ExecStart=" "$service_file" | sed 's/^ExecStart=[-@!+:]*//' | awk '{print $1}')
                if [ -n "$exec_start" ] && [ -f "$exec_start" ]; then
                    real_path=$(realpath "$exec_start" 2>/dev/null || readlink -f "$exec_start" 2>/dev/null)
                    if [ -n "$real_path" ]; then
                        TRACKED_PATHS+=("$real_path")
                        parent_dir=$(dirname "$real_path")
                        if ! is_protected_dir "$parent_dir"; then
                            TRACKED_PATHS+=("$parent_dir")
                        fi
                        echo -e "${CYAN}  → 从服务追踪到: $real_path${NC}"
                    fi
                fi

                working_dir=$(grep -E "^WorkingDirectory=" "$service_file" | sed 's/^WorkingDirectory=//' | xargs)
                if [ -n "$working_dir" ] && [ -d "$working_dir" ]; then
                    real_path=$(realpath "$working_dir" 2>/dev/null || readlink -f "$working_dir" 2>/dev/null)
                    if [ -n "$real_path" ] && ! is_protected_dir "$real_path"; then
                        TRACKED_PATHS+=("$real_path")
                        echo -e "${CYAN}  → 工作目录: $real_path${NC}"
                    fi
                fi
            fi
        done < <(find /etc/systemd/system/ -type f \( -name "*nezha-dashboard*" -o -name "*nezha.service*" \) ! -name "*nezha-agent*" 2>/dev/null)
    fi

    # 去重显示
    if [ ${#TRACKED_PATHS[@]} -gt 0 ]; then
        for path in "${TRACKED_PATHS[@]}"; do
            unique_paths["$path"]=1
        done

        echo -e "\n${GREEN}✓ 智能追踪发现以下Dashboard安装路径:${NC}"
        echo -e "${GREEN}✓ Intelligent tracking found these Dashboard paths:${NC}"
        for path in "${!unique_paths[@]}"; do
            if [ -e "$path" ]; then
                echo -e "${YELLOW}  📍 $path${NC}"
            fi
        done
    else
        echo -e "${GREEN}未追踪到Dashboard特殊安装路径${NC}"
        echo -e "${GREEN}No special Dashboard paths tracked${NC}"
    fi

    # D3: 检查/移除定时任务
    echo -e "\n${BLUE}[步骤D3] 检查Dashboard相关定时任务...${NC}"
    echo -e "${BLUE}[Step D3] Checking Dashboard-related cron jobs...${NC}"
    if ! command -v crontab &>/dev/null; then
        echo -e "${GREEN}系统无 crontab 命令，跳过定时任务检查${NC}"
        echo -e "${GREEN}No crontab command available, skipping cron check${NC}"
    else
        cron_result=$(crontab -l 2>/dev/null | grep -iE "nezha-dashboard|/nezha/dashboard" || echo "No crontab found")
        if [ "$cron_result" != "No crontab found" ]; then
            echo -e "${YELLOW}发现Dashboard相关定时任务:${NC}"
            echo -e "${YELLOW}Found Dashboard-related cron jobs:${NC}"
            echo "$cron_result"

            echo -e "${YELLOW}正在移除Dashboard相关定时任务...${NC}"
            echo -e "${YELLOW}Removing Dashboard-related cron jobs...${NC}"
            local filtered
            filtered=$(crontab -l 2>/dev/null | grep -v -iE "nezha-dashboard|/nezha/dashboard")
            if [ -z "$filtered" ]; then
                crontab -r 2>/dev/null
            else
                echo "$filtered" | crontab -
            fi
            echo -e "${GREEN}定时任务清理完成${NC}"
            echo -e "${GREEN}Cron jobs cleaned${NC}"
        else
            echo -e "${GREEN}未发现Dashboard相关定时任务${NC}"
            echo -e "${GREEN}No Dashboard-related cron jobs found${NC}"
        fi
    fi

    # D4: 停止并禁用Dashboard服务
    echo -e "\n${BLUE}[步骤D4] 停止并禁用Dashboard相关服务...${NC}"
    echo -e "${BLUE}[Step D4] Stopping and disabling Dashboard services...${NC}"
    # 匹配 *nezha-dashboard* 和 *nezha.service*，排除 *nezha-agent*
    dash_services=$(systemctl list-units --type=service --all 2>/dev/null | grep -iE "nezha-dashboard|nezha\.service" | grep -vi "nezha-agent" | awk '{print $1}')
    if [ -n "$dash_services" ]; then
        echo -e "${YELLOW}发现以下Dashboard相关服务:${NC}"
        echo -e "${YELLOW}Found the following Dashboard services:${NC}"
        echo "$dash_services"

        for service in $dash_services; do
            echo -e "${YELLOW}停止并禁用 $service...${NC}"
            echo -e "${YELLOW}Stopping and disabling $service...${NC}"
            systemctl stop "$service" 2>/dev/null
            systemctl disable "$service" 2>/dev/null
        done
        echo -e "${GREEN}Dashboard服务已停止并禁用${NC}"
        echo -e "${GREEN}Dashboard services stopped and disabled${NC}"
    else
        echo -e "${GREEN}未发现Dashboard相关服务${NC}"
        echo -e "${GREEN}No Dashboard services found${NC}"
    fi

    # D5: 强制终止Dashboard进程
    echo -e "\n${BLUE}[步骤D5] 强制终止Dashboard进程...${NC}"
    echo -e "${BLUE}[Step D5] Forcefully terminating Dashboard processes...${NC}"
    if pgrep -f "[n]ezha-dashboard" >/dev/null; then
        echo -e "${YELLOW}正在终止Dashboard进程...${NC}"
        echo -e "${YELLOW}Terminating Dashboard processes...${NC}"
        pkill -9 -f "[n]ezha-dashboard"
        sleep 1
        echo -e "${GREEN}Dashboard进程已终止${NC}"
        echo -e "${GREEN}Dashboard processes terminated${NC}"
    else
        echo -e "${GREEN}没有需要终止的Dashboard进程${NC}"
        echo -e "${GREEN}No Dashboard processes to terminate${NC}"
    fi

    # D6: 删除Dashboard服务文件
    echo -e "\n${BLUE}[步骤D6] 删除Dashboard服务文件...${NC}"
    echo -e "${BLUE}[Step D6] Removing Dashboard service files...${NC}"
    # 匹配 Dashboard 和通用 nezha 服务文件，排除 Agent
    dash_svc_files=$(find /etc/systemd/system/ -type f \( -name "*nezha-dashboard*" -o -name "*nezha.service*" \) ! -name "*nezha-agent*" 2>/dev/null)
    if [ -n "$dash_svc_files" ]; then
        echo -e "${YELLOW}发现以下Dashboard服务文件:${NC}"
        echo -e "${YELLOW}Found the following Dashboard service files:${NC}"
        echo "$dash_svc_files"

        echo -e "${YELLOW}删除Dashboard服务文件...${NC}"
        echo -e "${YELLOW}Removing Dashboard service files...${NC}"
        while IFS= read -r svc_file; do
            safe_remove "$svc_file" "$svc_file (Dashboard systemd unit)"
        done <<< "$dash_svc_files"
        echo -e "${GREEN}Dashboard服务文件已删除${NC}"
        echo -e "${GREEN}Dashboard service files removed${NC}"
    else
        echo -e "${GREEN}未发现Dashboard服务文件${NC}"
        echo -e "${GREEN}No Dashboard service files found${NC}"
    fi

    # D7: 删除Dashboard标准位置的文件和目录
    echo -e "\n${BLUE}[步骤D7] 删除Dashboard标准位置的目录和文件...${NC}"
    echo -e "${BLUE}[Step D7] Removing Dashboard directories and files in standard locations...${NC}"

    dash_directories=(
        "/opt/nezha/dashboard"
        "/opt/nezha-dashboard"
        "/usr/local/nezha/dashboard"
    )

    dash_binaries=(
        "/usr/local/bin/nezha-dashboard"
        "/usr/bin/nezha-dashboard"
        "/opt/nezha/dashboard/app"
    )

    for dir in "${dash_directories[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${YELLOW}删除Dashboard目录: $dir${NC}"
            echo -e "${YELLOW}Removing Dashboard directory: $dir${NC}"
            safe_remove "$dir" "$dir (Dashboard install dir)"
        fi
    done

    for bin in "${dash_binaries[@]}"; do
        if [ -f "$bin" ]; then
            echo -e "${YELLOW}删除Dashboard二进制文件: $bin${NC}"
            echo -e "${YELLOW}Removing Dashboard binary: $bin${NC}"
            safe_remove "$bin" "$bin (Dashboard binary)"
        fi
    done

    # 额外清理 docker-compose.yaml / .yml
    for compose_file in /opt/nezha/dashboard/docker-compose.yaml /opt/nezha/dashboard/docker-compose.yml /opt/nezha/docker-compose.yaml /opt/nezha/docker-compose.yml; do
        if [ -f "$compose_file" ]; then
            safe_remove "$compose_file" "$compose_file (Docker Compose config)"
        fi
    done

    # D8: 清理D2追踪到的路径
    if [ ${#unique_paths[@]} -gt 0 ]; then
        echo -e "\n${CYAN}[步骤D8] 🎯 清理Dashboard追踪到的路径...${NC}"
        echo -e "${CYAN}[Step D8] 🎯 Cleaning tracked Dashboard paths...${NC}"

        for path in "${!unique_paths[@]}"; do
            if [ -e "$path" ] || [ -L "$path" ]; then
                safe_remove "$path"
            fi
        done
    fi

    # D9: 全局 find 扫描 + 交互式确认
    echo -e "\n${BLUE}[步骤D9] 查找并删除Dashboard相关文件（全局搜索）...${NC}"
    echo -e "${BLUE}[Step D9] Finding and removing Dashboard-related files (global search)...${NC}"
    echo -e "${YELLOW}正在搜索Dashboard相关文件...${NC}"
    echo -e "${YELLOW}Searching for Dashboard-related files...${NC}"
    echo -e "${CYAN}注意: 图片/文档/媒体文件将自动跳过（非哪吒监控组件）${NC}"
    echo -e "${CYAN}Note: Images/documents/media files will be auto-skipped (not Nezha components)${NC}"

    temp_file=$(mktemp) || {
        echo -e "${RED}[错误] 无法创建临时文件，请检查 /tmp 权限${NC}"
        echo -e "${RED}[Error] Failed to create temporary file, check /tmp permissions${NC}"
        exit 1
    }
    register_temp_file "$temp_file"

    find /root /home /tmp /var/tmp /var/log /var/lib /etc /usr/local /opt /data /www \
        \( -path /var/lib/docker -prune \) -o \
        \( -path /var/lib/containerd -prune \) -o \
        \( -iname "*nezha*" -print \) 2>/dev/null > "$temp_file"

    if [ -s "$temp_file" ]; then
        echo -e "${YELLOW}发现以下Dashboard相关文件:${NC}"
        echo -e "${YELLOW}Found the following Dashboard-related files:${NC}"
        cat "$temp_file"

        echo -e "\n${YELLOW}是否删除这些文件? [y/N] ${NC}"
        echo -e "${YELLOW}Would you like to delete these files? [y/N] ${NC}"
        read -r response </dev/tty
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            while IFS= read -r file; do
                safe_remove "$file"
            done < "$temp_file"
            echo -e "${GREEN}文件已删除${NC}"
            echo -e "${GREEN}Files removed${NC}"
        else
            echo -e "${YELLOW}跳过删除文件${NC}"
            echo -e "${YELLOW}Skipping file removal${NC}"
        fi
    else
        echo -e "${GREEN}未发现Dashboard相关文件${NC}"
        echo -e "${GREEN}No Dashboard-related files found${NC}"
    fi

    # D10: Docker容器 + 镜像清理（4层纵深防御）
    echo -e "\n${BLUE}[步骤D10] 检查并清理Dashboard Docker容器...${NC}"
    echo -e "${BLUE}[Step D10] Checking and cleaning Dashboard Docker containers...${NC}"
    if command -v docker &> /dev/null; then
        declare -A dashboard_container_map
        TAB_CHAR=$(printf '\t')

        # === 第1层: Docker原生过滤器 — 捕获所有 nezha 容器 ===
        while IFS="$TAB_CHAR" read -r cid cname cimage; do
            [[ -n "$cid" ]] && dashboard_container_map["$cid"]="${cname}|${cimage}"
        done < <(docker ps -a --filter "name=*nezha*" --format "{{.ID}}\t{{.Names}}\t{{.Image}}" 2>/dev/null)

        # === 第1层补充: grep 补充匹配镜像名 ===
        while IFS="$TAB_CHAR" read -r cid cname cimage; do
            [[ -n "$cid" ]] && dashboard_container_map["$cid"]="${cname}|${cimage}"
        done < <(docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Image}}" 2>/dev/null | grep -iE "nezha-dashboard|nezha:")

        # === 第2层: 分类筛选 — 跳过 Agent 容器 ===
        local skipped_agent=0
        for cid in "${!dashboard_container_map[@]}"; do
            IFS='|' read -r cname cimage <<< "${dashboard_container_map[$cid]}"
            local cname_lower="${cname,,}"
            if [[ "$cname_lower" == *nezha-agent* ]]; then
                echo -e "${CYAN}  → 跳过Agent容器: $cname (Dashboard模式不处理Agent)${NC}"
                echo -e "${CYAN}  → Skipping Agent container: $cname (not handled in Dashboard mode)${NC}"
                unset 'dashboard_container_map[$cid]'
                skipped_agent=$((skipped_agent + 1))
            fi
        done

        if [ ${#dashboard_container_map[@]} -gt 0 ]; then
            echo -e "${YELLOW}发现以下Dashboard相关Docker容器:${NC}"
            echo -e "${YELLOW}Found the following Dashboard Docker containers:${NC}"
            for cid in "${!dashboard_container_map[@]}"; do
                IFS='|' read -r cname cimage <<< "${dashboard_container_map[$cid]}"
                printf "  %s\t%s\t%s\n" "$cid" "$cname" "$cimage"
            done

            echo -e "\n${YELLOW}是否停止并删除这些容器? [y/N] ${NC}"
            echo -e "${YELLOW}Would you like to stop and remove these containers? [y/N] ${NC}"
            read -r response </dev/tty
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                for cid in "${!dashboard_container_map[@]}"; do
                    IFS='|' read -r cname cimage <<< "${dashboard_container_map[$cid]}"

                    # === 第3层: docker inspect 逐容器验证 ===
                    verify_name=$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null | tr '[:upper:]' '[:lower:]')
                    verify_image=$(docker inspect --format '{{.Config.Image}}' "$cid" 2>/dev/null | tr '[:upper:]' '[:lower:]')

                    if [[ "$verify_name" == *nezha* ]] || [[ "$verify_image" == *nezha* ]]; then
                        echo -e "${YELLOW}停止并删除容器: $cid ($cname) [镜像: $cimage]${NC}"
                        echo -e "${YELLOW}Stopping and removing container: $cid ($cname) [Image: $cimage]${NC}"
                        docker stop "$cid" 2>/dev/null
                        docker rm "$cid" 2>/dev/null
                    else
                        echo -e "${RED}⚠️  容器 $cid ($cname) 未通过 nezha 验证，跳过删除${NC}"
                        echo -e "${RED}⚠️  Container $cid ($cname) failed nezha verification, skipping${NC}"
                    fi
                done
                echo -e "${GREEN}Dashboard容器已清理${NC}"
                echo -e "${GREEN}Dashboard containers cleaned${NC}"

                # === 第4层: 镜像删除（二次确认） ===
                nezha_images=$(docker images --format "{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}" 2>/dev/null | grep -iE "nezha")
                if [ -n "$nezha_images" ]; then
                    echo -e "\n${YELLOW}发现以下哪吒相关Docker镜像:${NC}"
                    echo -e "${YELLOW}Found the following Nezha Docker images:${NC}"
                    echo "$nezha_images"
                    echo -e "\n${YELLOW}是否删除这些镜像? [y/N] ${NC}"
                    echo -e "${YELLOW}Would you like to remove these images? [y/N] ${NC}"
                    read -r img_response </dev/tty
                    if [[ "$img_response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                        # 提取镜像ID并删除
                        echo "$nezha_images" | while IFS=$'\t' read -r img_tag img_id img_size; do
                            if [ -n "$img_id" ]; then
                                echo -e "${YELLOW}删除镜像: $img_tag ($img_id)${NC}"
                                docker rmi "$img_id" 2>/dev/null || docker rmi "$img_tag" 2>/dev/null
                            fi
                        done
                        echo -e "${GREEN}Dashboard镜像已删除${NC}"
                        echo -e "${GREEN}Dashboard images removed${NC}"
                    else
                        echo -e "${YELLOW}跳过镜像删除（可稍后手动清理）${NC}"
                        echo -e "${YELLOW}Skipping image removal (can be done manually later)${NC}"
                    fi
                else
                    echo -e "${GREEN}未发现哪吒相关Docker镜像${NC}"
                    echo -e "${GREEN}No Nezha Docker images found${NC}"
                fi
            else
                echo -e "${YELLOW}跳过Dashboard容器清理${NC}"
                echo -e "${YELLOW}Skipping Dashboard container cleanup${NC}"
            fi
        else
            if [ $skipped_agent -gt 0 ]; then
                echo -e "${GREEN}所有匹配容器均为Agent容器（已在Dashboard模式跳过）${NC}"
                echo -e "${GREEN}All matched containers are Agent containers (skipped in Dashboard mode)${NC}"
            else
                echo -e "${GREEN}未发现Dashboard相关Docker容器${NC}"
                echo -e "${GREEN}No Dashboard Docker containers found${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Docker未安装，跳过检查${NC}"
        echo -e "${YELLOW}Docker not installed, skipping check${NC}"
    fi

    # D11: systemctl daemon-reload
    echo -e "\n${BLUE}[步骤D11] 重新加载systemd配置...${NC}"
    echo -e "${BLUE}[Step D11] Reloading systemd configuration...${NC}"
    systemctl daemon-reload 2>/dev/null
    echo -e "${GREEN}systemd配置已重新加载${NC}"
    echo -e "${GREEN}systemd configuration reloaded${NC}"

    # D12: 最终验证
    echo -e "\n${BLUE}[步骤D12] 最终检查...${NC}"
    echo -e "${BLUE}[Step D12] Final check...${NC}"

    # 检查Dashboard进程
    if pgrep -f "[n]ezha-dashboard" >/dev/null; then
        echo -e "${RED}⚠️  警告: 仍然检测到Dashboard进程!${NC}"
        echo -e "${RED}⚠️  Warning: Dashboard processes still detected!${NC}"
        ps aux | grep -E "[n]ezha-dashboard"
    else
        echo -e "${GREEN}✓ 未检测到任何Dashboard进程${NC}"
        echo -e "${GREEN}✓ No Dashboard processes detected${NC}"
    fi

    # 检查Dashboard服务
    dash_services_remaining=$(systemctl list-units --type=service --all 2>/dev/null | grep -iE "nezha-dashboard|nezha\.service" | grep -vi "nezha-agent" | awk '{print $1}')
    if [ -n "$dash_services_remaining" ]; then
        echo -e "${RED}⚠️  警告: 仍然检测到Dashboard服务!${NC}"
        echo -e "${RED}⚠️  Warning: Dashboard services still detected!${NC}"
        echo "$dash_services_remaining"
    else
        echo -e "${GREEN}✓ 未检测到任何Dashboard服务${NC}"
        echo -e "${GREEN}✓ No Dashboard services detected${NC}"
    fi

    # 检查Docker容器
    if command -v docker &> /dev/null; then
        remaining_docker=$(docker ps -a --filter "name=*nezha*" --format "{{.Names}}" 2>/dev/null | grep -vi "nezha-agent" || true)
        if [ -n "$remaining_docker" ]; then
            echo -e "${YELLOW}⚠️  仍有Dashboard Docker容器残留:${NC}"
            echo -e "${YELLOW}⚠️  Remaining Dashboard Docker containers:${NC}"
            echo "$remaining_docker"
        else
            echo -e "${GREEN}✓ 未检测到Dashboard Docker容器${NC}"
            echo -e "${GREEN}✓ No Dashboard Docker containers detected${NC}"
        fi
    fi

    # 检查残留文件
    remaining_files=$(find /root /home /opt /usr/local /data /www /var/log /var/lib 2>/dev/null | grep -i "nezha" | grep -v "nezha-agent" | head -10)
    if [ -n "$remaining_files" ]; then
        echo -e "${YELLOW}⚠️  发现一些可能的Dashboard残留文件:${NC}"
        echo -e "${YELLOW}⚠️  Found some possible Dashboard remaining files:${NC}"
        echo "$remaining_files"
        echo -e "${YELLOW}如需手动清理，请检查这些文件${NC}"
        echo -e "${YELLOW}Please check these files for manual cleanup if needed${NC}"
    else
        echo -e "${GREEN}✓ 未发现任何Dashboard残留文件${NC}"
        echo -e "${GREEN}✓ No Dashboard remaining files detected${NC}"
    fi

    echo -e "\n${GREEN}✓ Dashboard (主控端) 清理完成!${NC}"
    echo -e "${GREEN}✓ Dashboard (Control Panel) cleanup complete!${NC}"
}

# ==============================================================================
#  模式调度 — 根据用户选择执行对应的清理函数
# ==============================================================================

case "$TARGET" in
    agent)
        cleanup_agent
        ;;
    dashboard)
        cleanup_dashboard
        ;;
    both)
        # Agent 先执行（处理 Agent 专属容器/文件），然后 Dashboard（处理剩余）
        cleanup_agent
        cleanup_dashboard
        ;;
esac

# ==============================================================================
#  结束横幅
# ==============================================================================

echo -e "\n${BLUE}=================================================================${NC}"
echo -e "${GREEN}           哪吒探针清理完成!                                     ${NC}"
echo -e "${GREEN}           Nezha cleanup complete!                               ${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e "${CYAN}v2.2: 统计+修复 — Usage Counter + Bug Fixes${NC}"
echo -e "${CYAN}v2.2: Usage Counter + Bug Fixes — Agent + Dashboard safe uninstall${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo -e "${YELLOW}如果您在清理后仍然遇到问题，可能需要考虑系统重启。${NC}"
echo -e "${YELLOW}If issues persist after cleanup, consider restarting your system.${NC}"
echo -e "\n${GREEN}感谢使用此脚本! 您的使用帮助我们持续改进。${NC}"
echo -e "${GREEN}Thank you for using this script! Your usage helps us improve.${NC}"

exit 0
