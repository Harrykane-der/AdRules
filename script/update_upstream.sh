#!/bin/bash
set -euo pipefail

# 导入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# 项目根目录
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_DIR="${ROOT_DIR}/tmp"
export FAILED_LOG="${ROOT_DIR}/download_failed.log"

# 检查依赖 (去除了 sed，添加了 tr)
check_deps curl tr xargs md5sum

# 准备目录：每次运行前清理旧的临时文件，避免废弃规则残留
rm -rf "${TMP_DIR}/content" "${TMP_DIR}/dns"
mkdir -p "${TMP_DIR}/content" "${TMP_DIR}/dns"
> "$FAILED_LOG"

# 下载任务处理函数
do_download() {
    local url="$1"
    local target_dir="$2"
    
    # 【哈希优化】使用 printf 避免附带换行符被计算，改用 cut 提取更标准
    local url_hash=$(printf "%s" "$url" | md5sum | cut -c 1-8)
    local original_filename=$(basename "$url")
    local filename="${url_hash}_${original_filename}"
    
    local filepath="${target_dir}/${filename}"
    local tmp_filepath="${filepath}.tmp"
    
    if download_file "$url" "$tmp_filepath"; then
        # 【I/O性能优化】放弃使用 sed -i，改用流式处理 (重定向 + tr)，速度大幅提升且兼容性更好
        {
            echo "! url: $url"
            tr -d '\r' < "$tmp_filepath"
        } > "$filepath"
        
        # 成功后删除临时文件
        rm -f "$tmp_filepath"
    else
        rm -f "$tmp_filepath"
        # 多进程并发写入日志
        echo "$url" >> "$FAILED_LOG"
    fi
}

# 导出函数和变量给 xargs 子进程使用
export -f do_download
export -f download_file
export -f log_info
export -f log_warn
export -f log_error
export NC GREEN YELLOW RED

# 规则链接 (清理了 dns_urls 中重复的 fqnovel-fxxk_ads)
content_urls=(
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.mini.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/gambling.mini.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/doh-vpn-proxy-bypass.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/dyndns.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/doh.txt"
  "https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockdns.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/ultimate.txt"
  "https://gh-proxy.com/raw.githubusercontent.com/changzhaoCZ/fqnovel-adrules/refs/heads/main/fqnovel-fxxk_ads"
  "https://ghproxy.net/https://raw.githubusercontent.com/changzhaoCZ/fqnovel-adrules/refs/heads/main/fq2.txt"
  "https://ghproxy.net/https://raw.githubusercontent.com/changzhaoCZ/fqnovel-adrules/refs/heads/main/qimao-ads"
  "https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockfilters.txt" 
  "https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-adguard.txt"
)

dns_urls=(
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.mini.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/gambling.mini.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/doh-vpn-proxy-bypass.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/dyndns.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/doh.txt"
  "https://gh-proxy.com/raw.githubusercontent.com/changzhaoCZ/fqnovel-adrules/refs/heads/main/fqnovel-fxxk_ads"
  "https://ghproxy.net/https://raw.githubusercontent.com/changzhaoCZ/fqnovel-adrules/refs/heads/main/fq2.txt"
  "https://ghproxy.net/https://raw.githubusercontent.com/changzhaoCZ/fqnovel-adrules/refs/heads/main/qimao-ads"
  "https://raw.githubusercontent.com/217heidai/adblockfilters/main/rules/adblockdomain.txt"
  "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/ultimate.txt"
  "https://gh-proxy.com/raw.githubusercontent.com/changzhaoCZ/fqnovel-adrules/refs/heads/main/fqnovel-fxxk_ads"
  "https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-adguard.txt"
)
log_info "开始并发下载规则..."

# 【参数安全优化】使用占位符将变量作为 bash 的参数 ($1, $2) 传入，避免由单引号引起的注入错误及路径空格问题
printf "%s\n" "${content_urls[@]}" | xargs -I {} -P 8 bash -c 'do_download "$1" "$2"' _ "{}" "${TMP_DIR}/content"
printf "%s\n" "${dns_urls[@]}"     | xargs -I {} -P 8 bash -c 'do_download "$1" "$2"' _ "{}" "${TMP_DIR}/dns"

if [ -s "$FAILED_LOG" ]; then
    log_error "以下链接下载失败:"
    cat "$FAILED_LOG"
else
    # 成功时清理空日志文件
    rm -f "$FAILED_LOG"
fi

log_info "下载任务完成。"
