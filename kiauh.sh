#!/usr/bin/env bash

#=======================================================================#
# Copyright (C) 2020 - 2024 Dominik Willner th33xitus@gmail.com
# This file is part of KIAUH - Klipper Installation And Update Helper
# https://github.com/dw-0/kiauh
# This file may be distributed under the terms of the GNU GPLv3 license
#=======================================================================#

set -e
clear -x

# make sure we have the correct permissions while running the script
umask 022

KIAUH_SRCDIR="$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")"

for script in "${KIAUH_SRCDIR}/scripts/"*.sh; do . "${script}"; done
for script in "${KIAUH_SRCDIR}/scripts/ui/"*.sh; do . "${script}"; done

function launch_kiauh_v5() {
    main_menu
}

function main() {
    launch_kiauh_v5
}

function select_best_mirror() {
    echo -e "\n\033[33m正在检测镜像站及直连延迟，请稍候...\033[0m"
    local mirrors=(
        "https://ghproxy.cn/"
        "https://ghfast.top/"
        "https://wget.la/"
        "https://hk.gh-proxy.com/"
        "https://gh-proxy.com/"
        "https://gh.zwy.one/"
    )

    local best_mirror_url=""
    local min_mirror_latency=99999

    echo "------------------------------------------------------------"
    printf "%-40s %s\n" "地址" "延迟 (ms)"
    echo "------------------------------------------------------------"

    # 1. 循环检测镜像站
    for url in "${mirrors[@]}"; do
        local domain=$(echo "$url" | sed 's|https://||' | cut -d/ -f1)
        # Ping 3次，超时1秒
        local latency=$(ping -c 3 -W 1 "$domain" 2>/dev/null | tail -1 | awk -F '/' '{print $5}' || true)
        if [[ -z "$latency" ]]; then
            printf "%-38s \033[31m%s\033[0m\n" "$url" "超时"
        else
            printf "%-38s \033[32m%s ms\033[0m\n" "$url" "$latency"
            # 更新最佳镜像记录
            local is_faster=$(awk -v lat="$latency" -v min="$min_mirror_latency" 'BEGIN {if (lat < min) print 1; else print 0}')
            if [[ "$is_faster" -eq 1 ]]; then
                min_mirror_latency=$latency
                best_mirror_url=$url
            fi
        fi
    done

    # 2. 检测 Github 直连延迟
    echo "------------------------------------------------------------"
    local github_latency=$(ping -c 3 -W 1 "github.com" 2>/dev/null | tail -1 | awk -F '/' '{print $5}' || true)
    local github_display_latency=$github_latency
    if [[ -z "$github_latency" ]]; then
        github_display_latency="超时"
        printf "%-40s \033[31m%s\033[0m\n" "github.com (直连)" "超时"
        github_latency=99999 # 设置为极大值以便比较
    else
        printf "%-40s \033[32m%s ms\033[0m\n" "github.com (直连)" "$github_latency"
    fi
    echo "------------------------------------------------------------"

    # 3. 智能对比：直连 vs 最佳镜像
    local final_choice_url=""
    local final_choice_msg=""
    local use_direct=0

    # 如果所有镜像都挂了，且直连也挂了
    if [[ "$best_mirror_url" == "" && "$github_latency" == "99999" ]]; then
        final_choice_url="https://ghproxy.cn/" # 保底默认
        final_choice_msg="全部超时 (默认使用 ghproxy.cn)"
    else
        # 比较 最佳镜像延迟 vs 直连延迟
        # 注意：如果 best_mirror_url 为空（所有镜像都超时），min_mirror_latency 依然是 99999
        local direct_is_winner=$(awk -v gl="$github_latency" -v ml="$min_mirror_latency" 'BEGIN {if (gl < ml) print 1; else print 0}')
        if [[ "$direct_is_winner" -eq 1 ]]; then
            # 直连更快
            use_direct=1
            final_choice_url="" # KIAUH 中直连就是变量为空
            final_choice_msg="Github 直连 ($github_display_latency ms)"
        else
            # 镜像更快
            use_direct=0
            final_choice_url="$best_mirror_url"
            final_choice_msg="$best_mirror_url ($min_mirror_latency ms)"
        fi
    fi

    # 4. 显示结果与询问
    echo -e "测速完成！建议使用: \033[36m$final_choice_msg\033[0m"
    echo ""
    echo "请选择要使用的 Git 模式:"
    echo " [Y] 是 (使用自动推荐: $final_choice_msg)"
    echo " [N] 否 (直连)"
    echo " [M] 手动 (输入自定义地址)"
    echo " [Q] 退出"
    echo ""

    local choice
    read -p "请输入选项 [Y/n/m/q] (默认 Y): " choice
    choice=${choice:-Y}

    case "${choice,,}" in
        y|yes)
            gitmirror="$final_choice_url"
            ;;
        n|no)
            gitmirror=""
            echo "已选择直连模式。"
            ;;
        m|manual)
            read -p "请输入自定义镜像地址 (例如 https://ghproxy.com/): " custom_input
            [[ "${custom_input}" != */ ]] && custom_input="${custom_input}/"
            gitmirror="$custom_input"
            ;;
        q|quit)
            exit 0
            ;;
        *)
            echo "无效输入，使用自动推荐。"
            gitmirror="$final_choice_url"
            ;;
    esac

    if [[ -z "$gitmirror" ]]; then
        echo -e "已设置: \033[32mGithub 直连\033[0m\n"
    else
        echo -e "已设置镜像地址: \033[32m$gitmirror\033[0m\n"
    fi
    sleep 1
}

function check_disk_space() {
    local MIN_REQ_KB=2621440
    local AVAILABLE_KB=$(df -k . | awk 'NR==2 {print $4}')
    local AVAILABLE_GB=$(awk "BEGIN {printf \"%.2f\", $AVAILABLE_KB/1024/1024}")
    echo -e "正在检测磁盘空间..."

    if [[ "$AVAILABLE_KB" -lt "$MIN_REQ_KB" ]]; then
        echo "------------------------------------------------------------"
        echo -e "\033[31m警告: 磁盘空间可能不足!\033[0m"
        echo "------------------------------------------------------------"
        echo -e "当前可用空间: \033[31m${AVAILABLE_GB} GB\033[0m"
        echo -e "建议最小空间: \033[32m2.50 GB\033[0m"
        echo ""
        echo "空间不足将导致安装失败。"
        echo "------------------------------------------------------------"
        local choice
        read -p "是否强制继续安装? [y/N]: " choice
        case "${choice,,}" in
            y|yes)
                echo -e "已忽略警告，\033[33m强制继续...\033[0m"
                ;;
            *)
                echo "操作已取消，请清理空间后再试。"
                exit 1
                ;;
        esac
    else
        echo -e "磁盘空间检测: \033[32m合格 (剩余 ${AVAILABLE_GB} GB)\033[0m"
    fi
    echo ""
}

check_disk_space

select_best_mirror

check_if_ratos
check_euid
init_logfile
set_globals
read_kiauh_ini
init_ini
main
