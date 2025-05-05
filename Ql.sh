#!/var/jb/bin/bash -e

# Dopamine 2.4.5 终极清理工具 v5.0
# 更新日期：2024-03-07
# 改进：路径修正/指纹增强/强制清理

export PATH=/var/jb/bin:/var/jb/sbin:/var/jb/usr/bin:/var/jb/usr/sbin:$PATH

# 颜色配置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Rootless环境配置
ROOTLESS_PREFIX="/var/jb"
SYSTEM_PATHS=(
    "/var/mobile"
    "/var/mobile/Documents"  # 新增文档目录
    "${ROOTLESS_PREFIX}/var/mobile"
    "/private/var/mobile"
    "/var/mobile/Library/Application Support"
    "${ROOTLESS_PREFIX}/var/mobile/Library/Caches"
    "/var/mobile/Containers/Data/Application"
    "${ROOTLESS_PREFIX}/var/mobile/Library/HTTPStorages"
    "/var/mobile/Media/Downloads"
    "/var/mobile/Library/WebClips"
    "${ROOTLESS_PREFIX}/var/mobile/Library/Containers"  # 修正拼写
)

# 智能安全排除
declare -A SAFE_EXCLUDE=(
    ["核心组件"]="${ROOTLESS_PREFIX}/usr/lib/*"
    ["系统应用"]="${ROOTLESS_PREFIX}/Applications/Sileo.app"
    ["钥匙串数据"]="/var/mobile/Library/Keychains"
)

# 增强文件指纹库
declare -A FILE_FINGERPRINTS=(
    ["临时文件"]="\.(tmp|temp|swp|bak|~)$"
    ["日志文件"]="(\.log(\.?[0-9]+)?$|crashlog|diagnostics"
    ["缓存数据"]="(Cache\.db$|CacheDelete|SessionStorage)"
    ["越狱痕迹"]="(Cydia|Sileo|Zebra|TrollStore|Procursus)"
    ["系统残留"]="(\.DS_Store|\.DS_Score|__MACOSX)"  # 新增.DS_Score
    ["下载残留"]="(\.deb$|\.ipa$|\.ipamobile$)"      # 覆盖.ipamobile
    ["大体积文件"]=".*"  # 特殊处理
)

# 路径构建器
build_find_paths() {
    printf "%s" "${SYSTEM_PATHS[@]@Q}"
}

# 排除构建器
build_exclude() {
    local clause=""
    for key in "${!SAFE_EXCLUDE[@]}"; do
        path=$(printf "%q" "${SAFE_EXCLUDE[$key]}")
        clause+=" -not -path ${path} -prune"
    done
    echo "$clause"
}

# 智能清理引擎
smart_clean() {
    local total=0
    declare -A results

    echo -e "${YELLOW}[+] 启动全维度深度扫描...${NC}"

    # 特殊处理大文件
    while IFS= read -r -d '' target; do
        [[ $(du -m "$target" | cut -f1) -ge 100 ]] && {
            results["大体积文件"]=$((results["大体积文件"]+1))
            ((total++))
        }
    done < <(eval find "${SYSTEM_PATHS[@]}" \( $(build_exclude) \) -type f -size +50M -print0 2>/dev/null)

    # 常规文件扫描
    for pattern in "${!FILE_FINGERPRINTS[@]}"; do
        [[ $pattern == "大体积文件" ]] && continue
        
        while IFS= read -r -d '' target; do
            results[$pattern]=$((results[$pattern]+1))
            ((total++))
        done < <(eval find "${SYSTEM_PATHS[@]}" \( $(build_exclude) \) -iregex ".*(${FILE_FINGERPRINTS[$pattern]})" -print0 2>/dev/null)
    done

    # 交互式清理
    for category in "${!results[@]}"; do
        count=${results[$category]}
        [[ $count -gt 0 ]] && {
            echo -e "${CYAN}发现 ${count} 个${category}${NC}"
            read -p "是否清理？[y/N] " confirm
            if [[ $confirm =~ [yY] ]]; then
                case $category in
                    "大体积文件")
                        find "${SYSTEM_PATHS[@]}" \( $(build_exclude) \) -type f -size +50M -exec rm -fv {} \;
                        ;;
                    *)
                        eval find "${SYSTEM_PATHS[@]}" \( $(build_exclude) \) -iregex ".*(${FILE_FINGERPRINTS[$category]})" -delete -f  # 强制删除
                        ;;
                esac
                echo -e "${GREEN}已清理 ${count} 个${category}${NC}"
            fi
        }
    done

    [[ $total -eq 0 ]] && echo -e "${GREEN}系统状态优异，未发现可清理项${NC}"
}

# 主程序
main() {
    clear
    echo -e "${GREEN}=== Dopamine 2.4.5 终极清理工具 v5.0 ==="
    echo -e "${RED}⚠️ 操作前请通过Sileo创建RootFS快照！${NC}\n"
    
    [[ "$1" == "-v" ]] && DEBUG=1
    
    smart_clean
    
    echo -e "\n${GREEN}✅ 清理完成，建议操作："
    echo -e "1. 执行 'ldrestart' 重载守护进程"
    echo -e "2. 使用 'diskusage /var/jb' 查看空间分布"
    echo -e "3. 重启设备确保完全生效${NC}"
}

# 权限验证
if [[ $(id -u) -ne 0 ]]; then
    echo -e "${RED}✖️ 请使用Root权限执行：sudo $0${NC}"
    exit 1
fi

main "$@"
