#!/system/bin/sh
# ============================================================
# 落幕清理  v1.5
#
# Root / 无Root
# ============================================================

SCRIPT_VERSION="1.5"

# ---------- 云端配置 ----------
COUNT_HIT_URL="https://countapi.mileshilliard.com/api/v1/hit/luomu-clean-2026"
COUNT_GET_URL="https://countapi.mileshilliard.com/api/v1/get/luomu-clean-2026"
# 多源更新（任一成功即可）
UPDATE_VER_URLS="
https://cdn.jsdelivr.net/gh/LMNB4/-LMNB4@main/version.txt
https://raw.githubusercontent.com/LMNB4/-LMNB4/main/version.txt
https://ghproxy.net/https://raw.githubusercontent.com/LMNB4/-LMNB4/main/version.txt
"
UPDATE_SCRIPT_URLS="
https://cdn.jsdelivr.net/gh/LMNB4/-LMNB4@main/落幕清理.sh
https://raw.githubusercontent.com/LMNB4/-LMNB4/main/落幕清理.sh
https://ghproxy.net/https://raw.githubusercontent.com/LMNB4/-LMNB4/main/%E8%90%BD%E5%B9%95%E6%B8%85%E7%90%86.sh
"

# ---------- 颜色 ----------
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
C='\033[0;36m'
W='\033[1;37m'
GR='\033[0;90m'
P='\033[0;35m'
RST='\033[0m'
BOLD='\033[1m'

IS_ROOT=0
SCRIPT_PATH="$0"

# ---------- 计时 ----------
_START_TS=0
timer_start() {
    _START_TS=$(date +%s 2>/dev/null)
    [ -z "$_START_TS" ] && _START_TS=0
}
timer_end() {
    local end cost m s
    end=$(date +%s 2>/dev/null)
    [ -z "$end" ] && end=0
    if [ "$_START_TS" -gt 0 ] 2>/dev/null && [ "$end" -ge "$_START_TS" ] 2>/dev/null; then
        cost=$((end - _START_TS))
        m=$((cost / 60))
        s=$((cost % 60))
        if [ "$m" -gt 0 ]; then
            echo "  ${GR}耗时 ${W}${m}${GR} 分 ${W}${s}${GR} 秒${RST}"
        else
            echo "  ${GR}耗时 ${W}${s}${GR} 秒${RST}"
        fi
    fi
}

line() {
    echo "${GR}  ────────────────────────────────────────${RST}"
}

# ---------- 网络工具 ----------
http_get() {
    local url="$1" out
    if command -v curl >/dev/null 2>&1; then
        out=$(curl -fsSL -A "Mozilla/5.0" --connect-timeout 8 --max-time 20 "$url" 2>/dev/null) && { printf '%s' "$out"; return 0; }
    fi
    if command -v wget >/dev/null 2>&1; then
        out=$(wget -q -O - -T 20 --user-agent="Mozilla/5.0" "$url" 2>/dev/null) && { printf '%s' "$out"; return 0; }
    fi
    return 1
}

http_get_file() {
    local url="$1" out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -A "Mozilla/5.0" --connect-timeout 8 --max-time 90 -o "$out" "$url" 2>/dev/null && [ -s "$out" ] && return 0
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$out" -T 90 --user-agent="Mozilla/5.0" "$url" 2>/dev/null && [ -s "$out" ] && return 0
    fi
    return 1
}

http_get_first() {
    local u body
    for u in $1; do
        [ -z "$u" ] && continue
        body=$(http_get "$u") || continue
        [ -n "$body" ] || continue
        printf '%s' "$body"
        return 0
    done
    return 1
}

http_get_file_first() {
    local out="$1" u
    shift
    for u in $*; do
        [ -z "$u" ] && continue
        rm -f "$out" 2>/dev/null
        if http_get_file "$u" "$out"; then
            return 0
        fi
    done
    return 1
}

confirm() {
    local msg="${1:-确认执行？}"
    echo -n "  ${Y}${msg} [y/N] › ${RST}"
    read _ans
    case "$_ans" in
        y|Y|yes|YES) return 0 ;;
        *) echo "  ${GR}已取消${RST}"; echo ""; return 1 ;;
    esac
}

# ---------- 使用次数（匿名、失败忽略） ----------
report_usage() {
    (
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL --connect-timeout 3 --max-time 5 "$COUNT_HIT_URL" >/dev/null 2>&1
        elif command -v wget >/dev/null 2>&1; then
            wget -q -O /dev/null -T 5 "$COUNT_HIT_URL" >/dev/null 2>&1
        fi
    ) &
}

# ---------- 云更新 ----------
check_update() {
    local remote tmp dl_ver dir targets tg ok
    echo ""
    echo "  ${C}…${RST} 检查更新"
    remote=$(http_get_first "$UPDATE_VER_URLS" | tr -d '\r\n\t ' | head -c 32)
    if [ -z "$remote" ]; then
        echo "  ${Y}!${RST} 无法连接更新服务器"
        echo "  ${GR}可稍后重试，或检查网络/代理${RST}"
        echo ""
        return 0
    fi
    if [ "$remote" = "$SCRIPT_VERSION" ]; then
        echo "  ${G}✓${RST} 已是最新版 ${W}v${SCRIPT_VERSION}${RST}"
        echo ""
        return 0
    fi

    echo "  ${Y}发现新版本 ${W}v${remote}${RST} ${GR}(当前 v${SCRIPT_VERSION})${RST}"
    echo -n "  ${C}是否更新？[y/N] › ${RST}"
    read ans
    case "$ans" in
        y|Y|yes|YES)
            tmp="/data/local/tmp/.luomu_update_$$.sh"
            [ -w /data/local/tmp ] 2>/dev/null || tmp="/sdcard/.luomu_update_$$.sh"
            echo "  ${C}…${RST} 正在下载"
            if http_get_file_first "$tmp" $UPDATE_SCRIPT_URLS; then
                if [ -s "$tmp" ] && grep -q "落幕清理\|SCRIPT_VERSION" "$tmp" 2>/dev/null; then
                    dl_ver=$(grep -m1 'SCRIPT_VERSION=' "$tmp" 2>/dev/null | head -1 | cut -d'"' -f2)
                    if [ -n "$dl_ver" ] && [ "$dl_ver" != "$remote" ]; then
                        echo "  ${R}✕ 脚本 v${dl_ver} 与 version.txt(v${remote}) 不一致${RST}"
                        rm -f "$tmp" 2>/dev/null
                        echo ""
                        return 0
                    fi
                    ok=0
                    for tg in "$SCRIPT_PATH" "/sdcard/落幕清理.sh" "/storage/emulated/0/落幕清理.sh"; do
                        [ -z "$tg" ] && continue
                        dir=$(dirname "$tg" 2>/dev/null)
                        [ -d "$dir" ] || continue
                        if cp -f "$tmp" "$tg" 2>/dev/null; then
                            chmod 755 "$tg" 2>/dev/null
                            ok=1
                            echo "  ${G}✓${RST} 已写入 $tg"
                        fi
                    done
                    rm -f "$tmp" 2>/dev/null
                    if [ "$ok" = "1" ]; then
                        echo "  ${G}✓ 更新完成 → v${dl_ver:-$remote}${RST}"
                        echo "  ${Y}请重新运行${RST}"
                        echo ""
                        exit 0
                    fi
                    echo "  ${R}✕ 无法写入脚本${RST}"
                else
                    echo "  ${R}✕ 下载文件无效${RST}"
                    rm -f "$tmp" 2>/dev/null
                fi
            else
                echo "  ${R}✕ 下载失败${RST}"
            fi
            ;;
        *)
            echo "  ${GR}已跳过${RST}"
            ;;
    esac
    echo ""
}

# ---------- 开屏 ----------
splash() {
    clear
    echo ""
    echo ""
    clear; echo ""; echo ""; echo "                    ${GR}·${RST}"; sleep 0.06
    clear; echo ""; echo ""; echo "                   ${GR}· ·${RST}"; sleep 0.06
    clear; echo ""; echo ""; echo "                  ${P}· 落 ·${RST}"; sleep 0.08
    clear; echo ""; echo ""; echo "                 ${P}· 落幕 ·${RST}"; sleep 0.08
    clear; echo ""; echo ""; echo "                ${P}· 落幕清 ·${RST}"; sleep 0.08
    clear; echo ""; echo ""
    echo "${P}  ╔══════════════════════════════════════╗${RST}"
    echo "${P}  ║${RST}                                      ${P}║${RST}"
    echo "${P}  ║${RST}          ${W}${BOLD}落  幕  清  理${RST}            ${P}║${RST}"
    echo "${P}  ║${RST}              ${GR}v${SCRIPT_VERSION}${RST}                  ${P}║${RST}"
    echo "${P}  ║${RST}                                      ${P}║${RST}"
    echo "${P}  ╚══════════════════════════════════════╝${RST}"
    sleep 0.2
    echo ""
    printf "  ${GR}"
    local i
    for i in 1 2 3 4 5 6; do
        printf "▓"
        sleep 0.05
    done
    printf "${RST}\n"
    sleep 0.1
}

# ---------- 设备信息 ----------
show_device_info() {
    local model brand release sdk kernel serial android_id spatch market mode
    model=$(getprop ro.product.model 2>/dev/null)
    brand=$(getprop ro.product.brand 2>/dev/null)
    release=$(getprop ro.build.version.release 2>/dev/null)
    sdk=$(getprop ro.build.version.sdk 2>/dev/null)
    kernel=$(uname -r 2>/dev/null)
    serial=$(getprop ro.serialno 2>/dev/null)
    [ -z "$serial" ] && serial=$(getprop ro.boot.serialno 2>/dev/null)
    android_id=$(settings get secure android_id 2>/dev/null)
    case "$android_id" in
        ""|null|*"Failure"*|*"error"*|*"Error"*) android_id="" ;;
    esac
    spatch=$(getprop ro.build.version.security_patch 2>/dev/null)
    market=$(getprop ro.product.marketname 2>/dev/null)
    [ -z "$market" ] && market=$(getprop ro.product.odm.marketname 2>/dev/null)

    if [ "$IS_ROOT" = "1" ]; then
        mode="${G}Root${RST}"
    else
        mode="${Y}无Root${RST}"
    fi

    echo "  ${C}┌─ 设备信息${RST}"
    echo "  ${C}│${RST}"
    echo "  ${C}│${RST}  模式    $mode"
    [ -n "$brand" ] && echo "  ${C}│${RST}  品牌    ${W}${brand}${RST}"
    [ -n "$model" ] && echo "  ${C}│${RST}  型号    ${W}${model}${RST}"
    [ -n "$market" ] && echo "  ${C}│${RST}  市场名  ${W}${market}${RST}"
    [ -n "$release" ] && echo "  ${C}│${RST}  系统    ${W}Android ${release}${RST} ${GR}(API ${sdk})${RST}"
    if [ -n "$kernel" ]; then
        [ ${#kernel} -gt 28 ] && kernel="${kernel:0:26}.."
        echo "  ${C}│${RST}  内核    ${W}${kernel}${RST}"
    fi
    [ -n "$spatch" ] && echo "  ${C}│${RST}  安补    ${W}${spatch}${RST}"
    [ -n "$serial" ] && echo "  ${C}│${RST}  序列号  ${GR}${serial}${RST}"
    [ -n "$android_id" ] && echo "  ${C}│${RST}  Android ID  ${GR}${android_id}${RST}"
    echo "  ${C}│${RST}"
    echo "  ${C}└──────────────────────────────${RST}"
    echo ""
}

title() {
    clear
    echo ""
    echo "${P}  ╔══════════════════════════════════════╗${RST}"
    echo "${P}  ║${RST}          ${W}${BOLD}落  幕  清  理${RST}            ${P}║${RST}"
    echo "${P}  ║${RST}              ${GR}v${SCRIPT_VERSION}${RST}                  ${P}║${RST}"
    echo "${P}  ╚══════════════════════════════════════╝${RST}"
    echo ""
}

# ---------- Root 检测 ----------
detect_root() {
    if [ "$(id -u)" = "0" ]; then
        IS_ROOT=1
        return 0
    fi
    # 部分环境 su 可用
    if su -c 'id -u' 2>/dev/null | grep -q '^0$'; then
        IS_ROOT=1
        return 0
    fi
    IS_ROOT=0
    return 1
}

get_all_users() {
    local ids
    ids=$(pm list users 2>/dev/null | grep -oE '[0-9]+' | sort -u)
    if [ -z "$ids" ]; then
        ids="0"
        for d in /data/user/*; do
            [ -d "$d" ] || continue
            u=$(basename "$d")
            echo "$u" | grep -qE '^[0-9]+$' && ids="$ids $u"
        done
        ids=$(echo "$ids" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    fi
    echo "$ids"
}

find_resetprop() {
    if command -v resetprop >/dev/null 2>&1; then
        echo "resetprop"
    elif [ -x /data/adb/magisk/resetprop ]; then
        echo "/data/adb/magisk/resetprop"
    elif [ -x /data/adb/ksu/bin/resetprop ]; then
        echo "/data/adb/ksu/bin/resetprop"
    else
        local f
        f=$(ls /data/adb/modules/*/resetprop 2>/dev/null | head -1)
        [ -n "$f" ] && [ -x "$f" ] && echo "$f" || echo ""
    fi
}

rand_hex() {
    local len=${1:-16}
    cat /dev/urandom 2>/dev/null | tr -dc 'a-f0-9' | head -c "$len"
}

rand_num() {
    local len=${1:-8}
    cat /dev/urandom 2>/dev/null | tr -dc '1-9' | head -c "$len"
}

cmp_line() {
    local name="$1" old="$2" new="$3" o n
    o="$old"; n="$new"
    [ ${#o} -gt 22 ] && o="${o:0:20}.."
    [ ${#n} -gt 22 ] && n="${n:0:20}.."
    [ -z "$o" ] && o="(空)"
    [ -z "$n" ] && n="(空)"
    printf "  ${G}✓${RST} %-12s\n" "$name"
    printf "      ${GR}旧${RST} %-22s ${C}→${RST} ${W}%s${RST}\n" "$o" "$n"
}

# ============================================================
# 解析游戏包名
# ============================================================
resolve_game() {
    case "$1" in
        codev)   echo "tmgp.codev|codev|valorant|无畏" ;;
        pubgmhd) echo "pubgmhd|hpjy|和平" ;;
        *)       echo "" ;;
    esac
}

game_name() {
    case "$1" in
        codev)   echo "无畏契约" ;;
        pubgmhd) echo "和平精英" ;;
        *)       echo "未知" ;;
    esac
}

# ============================================================
# ROOT：游戏清理
# ============================================================
do_clean_game_root() {
    local key="$1"
    local pattern gname packages users
    pattern=$(resolve_game "$key")
    gname=$(game_name "$key")
    [ -z "$pattern" ] && { echo "  ${R}未知游戏${RST}"; return 1; }

    title
    echo "  ${C}▸${RST} 清理 ${W}${gname}${RST}"
    line
    echo ""
    confirm "确认清理 ${gname}？" || return 0
    timer_start

    packages=$(pm list packages 2>/dev/null | grep -iE "$pattern" | cut -d: -f2)
    if [ -z "$packages" ]; then
        echo "  ${R}✕ 未检测到 ${gname}${RST}"
        echo ""
        return 0
    fi
    echo "  ${G}✓${RST} 包名："
    for p in $packages; do echo "    ${GR}·${RST} ${W}$p${RST}"; done
    users=$(get_all_users)
    echo "  ${G}✓${RST} 用户：${GR}$users${RST}"
    echo ""

    for p in $packages; do am force-stop "$p" 2>/dev/null; done
    echo "  ${G}✓${RST} 已停止进程"
    echo ""

    local uid pkg data_dir
    for uid in $users; do
        for pkg in $packages; do
            echo "  ${Y}📂${RST} ${W}$pkg${RST} ${GR}(用户 $uid)${RST}"
            for data_dir in "/data/user/$uid/$pkg" "/data/user_de/$uid/$pkg"; do
                [ -d "$data_dir" ] || continue
                [ -d "$data_dir/shared_prefs" ] && rm -rf "$data_dir/shared_prefs" 2>/dev/null && echo "    ${G}✓${RST} shared_prefs"
                [ -d "$data_dir/cache" ] && rm -rf "$data_dir/cache"/* 2>/dev/null && echo "    ${G}✓${RST} cache"
                rm -rf "$data_dir/code_cache" "$data_dir/no_backup" 2>/dev/null
                if [ -d "$data_dir/databases" ]; then
                    find "$data_dir/databases" -type f -size -1M -exec rm -f {} \; 2>/dev/null
                    echo "    ${G}✓${RST} databases 小文件"
                fi
                if [ -d "$data_dir/files" ]; then
                    find "$data_dir/files" -maxdepth 2 \( \
                        -name "ace_*" -o -name "*.mark" -o -name "*.ban" -o \
                        -name "hwid*" -o -name "device*" -o -name "blacklist*" -o \
                        -name "*_tmp.dat" -o -name "fp.dat" -o -name "risk*" \
                    \) -type f -exec rm -f {} \; 2>/dev/null
                    rm -rf \
                        "$data_dir/files/com.tencent.qimei.sdk.QimeiSDK" \
                        "$data_dir/files/com.tencent.beacon" \
                        "$data_dir/files/com.tencent.apm" \
                        "$data_dir/files/com.tencent.msdk" \
                        "$data_dir/files/tbs" "$data_dir/files/ace" "$data_dir/files/ACE" \
                        "$data_dir/files/anticheat" "$data_dir/files/turing" \
                        "$data_dir/files/app_turingdfp" "$data_dir/files/beacon" \
                        "$data_dir/files/ano_tmp" "$data_dir/files/perfsight" 2>/dev/null
                    find "$data_dir/files" -type f -size -1M -exec rm -f {} \; 2>/dev/null
                    echo "    ${G}✓${RST} files 标记与小文件"
                fi
            done
            local bases base sub ext
            if [ "$uid" = "0" ]; then
                bases="/sdcard /storage/emulated/0"
            else
                bases="/storage/emulated/$uid /mnt/user/$uid/emulated/0 /data/media/$uid"
            fi
            for base in $bases; do
                for sub in data obb; do
                    ext="$base/Android/$sub/$pkg"
                    [ -d "$ext" ] || continue
                    rm -rf "$ext/cache"/* 2>/dev/null
                    find "$ext" -type f -size -1M -exec rm -f {} \; 2>/dev/null
                    echo "    ${G}✓${RST} 外部 $sub"
                done
            done
            rm -f /data/dalvik-cache/*"$pkg"* /data/dalvik-cache/arm/*"$pkg"* /data/dalvik-cache/arm64/*"$pkg"* 2>/dev/null
            rm -f /data/system/package_cache/*"$pkg"* 2>/dev/null
            echo ""
        done
    done
    rm -rf /data/local/tmp/ace_*.mark /data/local/tmp/*.ban 2>/dev/null
    rm -rf /data/system/dropbox/* /data/tombstones/* /data/anr/* 2>/dev/null
    line
    echo "  ${G}${BOLD}✓ ${gname} 清理完成${RST}"
    timer_end
    line
    echo ""
}

# ============================================================
# 无 ROOT：游戏清理（最大化）
# ============================================================
do_clean_game_noroot() {
    local key="$1"
    local pattern gname packages
    pattern=$(resolve_game "$key")
    gname=$(game_name "$key")
    [ -z "$pattern" ] && { echo "  ${R}未知游戏${RST}"; return 1; }

    title
    echo "  ${Y}▸${RST} [无Root] 清理 ${W}${gname}${RST}"
    line
    echo ""
    confirm "确认清理 ${gname}？" || return 0
    timer_start

    packages=$(pm list packages 2>/dev/null | grep -iE "$pattern" | cut -d: -f2)
    if [ -z "$packages" ]; then
        echo "  ${R}✕ 未检测到 ${gname}${RST}"
        echo ""
        return 0
    fi
    echo "  ${G}✓${RST} 包名："
    for p in $packages; do echo "    ${GR}·${RST} ${W}$p${RST}"; done
    echo ""

    local pkg ok
    for pkg in $packages; do
        echo "  ${Y}▸${RST} ${W}$pkg${RST}"

        # 停进程（部分环境无 root 也可用）
        if am force-stop "$pkg" 2>/dev/null; then
            echo "    ${G}✓${RST} force-stop"
        else
            echo "    ${GR}· force-stop 不可用${RST}"
        fi

        # pm clear：清空应用全部数据（无 root 在 adb/部分 shell 可用）
        # 会清掉登录等，先尝试仅清 cache 相关路径
        ok=0
        for base in \
            /sdcard/Android/data/$pkg \
            /storage/emulated/0/Android/data/$pkg \
            /sdcard/Android/obb/$pkg \
            /storage/emulated/0/Android/obb/$pkg
        do
            if [ -d "$base" ]; then
                if rm -rf "$base/cache" 2>/dev/null; then
                    echo "    ${G}✓${RST} 外部 cache: $base/cache"
                    ok=1
                fi
                # 小文件标记
                find "$base" -type f \( -name '*.mark' -o -name 'ace_*' -o -name '*.ban' -o -name 'risk*' \) -exec rm -f {} \; 2>/dev/null
                find "$base" -type f -size -512k 2>/dev/null | while read -r f; do
                    case "$f" in
                        */files/*|*/cache/*|*/code_cache/*) rm -f "$f" 2>/dev/null ;;
                    esac
                done
            fi
        done

        # 尝试 pm clear（会清空整个应用数据，提示用户）
        # 无 root 默认不做 pm clear，避免误清登录；改为可选
        # 这里尽量清 media / 外部
        for base in /sdcard/Android/media/$pkg /storage/emulated/0/Android/media/$pkg; do
            [ -d "$base" ] && rm -rf "$base"/* 2>/dev/null && echo "    ${G}✓${RST} media 缓存" && ok=1
        done

        # 应用自带清缓存接口（Android 有时可用）
        if command -v cmd >/dev/null 2>&1; then
            cmd package compile --reset "$pkg" >/dev/null 2>&1
        fi

        if [ "$ok" = "0" ]; then
            echo "    ${Y}!${RST} 外部目录不可写"
        fi
        echo ""
    done

    # 无 root 可清的公共目录
    for d in \
        /sdcard/tencent \
        /storage/emulated/0/tencent \
        /sdcard/Android/data/com.tencent.mobileqq/cache/share
    do
        [ -e "$d" ] && rm -rf "$d" 2>/dev/null && echo "  ${G}✓${RST} 已删 $d"
    done

    line
    echo "  ${G}${BOLD}✓ ${gname} 清理完成${RST}"
    timer_end
    line
    echo ""
}

# 无 Root：可选「彻底清空应用数据」
do_pm_clear_noroot() {
    local key="$1"
    local pattern gname packages pkg
    pattern=$(resolve_game "$key")
    gname=$(game_name "$key")
    packages=$(pm list packages 2>/dev/null | grep -iE "$pattern" | cut -d: -f2)
    if [ -z "$packages" ]; then
        echo "  ${R}✕ 未检测到 ${gname}${RST}"
        return 0
    fi
    title
    echo "  ${R}⚠ pm clear 将清空全部数据（含登录）${RST}"
    line
    for pkg in $packages; do
        echo "  · $pkg"
    done
    echo ""
    echo -n "  ${Y}确定？[y/N] › ${RST}"
    read ans
    case "$ans" in
        y|Y)
            timer_start
            for pkg in $packages; do
                am force-stop "$pkg" 2>/dev/null
                if pm clear "$pkg" 2>/dev/null; then
                    echo "  ${G}✓${RST} pm clear $pkg"
                else
                    echo "  ${R}✕${RST} pm clear 失败: $pkg（权限不足）"
                fi
            done
            timer_end
            ;;
        *) echo "  ${GR}已取消${RST}" ;;
    esac
    echo ""
}

# ============================================================
# ROOT：设备标识
# ============================================================
do_reset_identity_root() {
    title
    echo "  ${P}▸${RST} 设备标识刷新"
    line
    echo ""
    confirm "确认刷新设备标识？" || return 0
    timer_start

    local rp users
    rp=$(find_resetprop)
    users=$(get_all_users)

    local old_id new_id
    old_id=$(settings get secure android_id 2>/dev/null)
    new_id=$(rand_hex 16)
    [ -z "$new_id" ] && new_id=$(date +%s | md5sum 2>/dev/null | head -c 16)
    settings put secure android_id "$new_id" 2>/dev/null
    cmp_line "Android ID" "$old_id" "$new_id"
    sleep 0.08

    pm clear com.google.android.gms >/dev/null 2>&1
    pm clear com.google.android.gsf >/dev/null 2>&1
    cmd adid reset 2>/dev/null
    rm -rf /data/data/com.google.android.gms/cache/* 2>/dev/null
    rm -rf /data/data/com.google.android.gms/shared_prefs/adid.xml 2>/dev/null
    cmp_line "广告 ID" "(系统)" "已重置"
    sleep 0.08

    local uid
    for uid in $users; do
        rm -f "/data/system/users/$uid/settings_ssaid.xml" 2>/dev/null
    done
    cmp_line "SSAID" "(已存在)" "已清除"
    sleep 0.08

    local old_serial new_serial
    old_serial=$(getprop ro.serialno 2>/dev/null)
    [ -z "$old_serial" ] && old_serial=$(getprop ro.boot.serialno 2>/dev/null)
    new_serial=$(rand_num 8)
    [ -z "$new_serial" ] && new_serial=$(date +%s | tail -c 9)
    if [ -n "$rp" ]; then
        $rp -f -n ro.serialno "$new_serial" 2>/dev/null
        $rp -f -n ro.boot.serialno "$new_serial" 2>/dev/null
        $rp -f -n vendor.serialno "$new_serial" 2>/dev/null
    fi
    local tmp_serial="/data/local/tmp/.lm_serial"
    echo "$new_serial" > "$tmp_serial" 2>/dev/null
    chmod 644 "$tmp_serial" 2>/dev/null
    local old_enf path serial_ok=0
    old_enf=$(getenforce 2>/dev/null)
    setenforce 0 2>/dev/null
    for path in \
        /sys/devices/soc0/serial_number \
        /sys/devices/platform/soc/serial_number \
        /sys/class/android_usb/android0/iSerial
    do
        [ -e "$path" ] || continue
        mount | grep -q "$path" && umount "$path" 2>/dev/null
        mount --bind "$tmp_serial" "$path" 2>/dev/null && serial_ok=$((serial_ok+1))
    done
    [ "$old_enf" = "Enforcing" ] && setenforce 1 2>/dev/null
    cmp_line "序列号" "$old_serial" "$new_serial"
    sleep 0.08

    local wlan old_mac new_mac
    wlan=$(ip link 2>/dev/null | grep -oE 'wlan[0-9]+' | head -1)
    if [ -n "$wlan" ]; then
        old_mac=$(ip link show "$wlan" 2>/dev/null | grep -oE 'link/ether [0-9a-f:]+' | awk '{print $2}')
        new_mac=$(rand_hex 10 | sed 's/../&:/g;s/:$//')
        [ -z "$new_mac" ] && new_mac="00:00:11:22:33"
        ip link set "$wlan" address "02:$new_mac" 2>/dev/null
        cmp_line "WiFi MAC" "$old_mac" "02:$new_mac"
    else
        cmp_line "WiFi MAC" "(无接口)" "跳过"
    fi
    sleep 0.08

    local old_bt new_bt
    old_bt=$(settings get secure bluetooth_address 2>/dev/null)
    new_bt=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | sed 's/-//g;s/../&:/g' | head -c 17 | tr 'a-z' 'A-Z')
    [ -z "$new_bt" ] && new_bt="02:00:00:00:00:01"
    settings put secure bluetooth_address "$new_bt" 2>/dev/null
    cmp_line "蓝牙 MAC" "$old_bt" "$new_bt"
    sleep 0.08

    local old_oaid new_oaid
    old_oaid=$(cat /data/system/oaid_persistence_0 2>/dev/null)
    new_oaid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 16)
    [ -z "$new_oaid" ] && new_oaid=$(rand_hex 16)
    echo "$new_oaid" > /data/system/oaid_persistence_0 2>/dev/null
    cmp_line "OAID" "$old_oaid" "$new_oaid"
    sleep 0.08

    local old_vaid new_vaid
    old_vaid=$(cat /data/system/vaid_persistence_platform 2>/dev/null)
    new_vaid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 16)
    [ -z "$new_vaid" ] && new_vaid=$(rand_hex 16)
    echo "$new_vaid" > /data/system/vaid_persistence_platform 2>/dev/null
    cmp_line "VAID" "$old_vaid" "$new_vaid"
    sleep 0.08

    local old_uuid new_uuid
    old_uuid=$(settings get global extm_uuid 2>/dev/null)
    new_uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    [ -z "$new_uuid" ] && new_uuid="$(date +%s)-$(rand_hex 8)"
    settings put global extm_uuid "$new_uuid" 2>/dev/null
    settings put system key_mqs_uuid "$new_uuid" 2>/dev/null
    settings put global gcbooster_uuid "$new_uuid" 2>/dev/null
    cmp_line "UUID" "$old_uuid" "$new_uuid"

    dmesg -c >/dev/null 2>&1
    logcat -c >/dev/null 2>&1
    cmp_line "系统日志" "(旧)" "已清空"

    echo ""
    line
    echo "  ${G}${BOLD}✓ 设备标识刷新完成${RST}"
    timer_end
    line
    echo ""
}

# 无 ROOT：设备标识（能改多少改多少）
do_reset_identity_noroot() {
    title
    echo "  ${Y}▸${RST} [无Root] 设备标识"
    line
    echo ""
    confirm "确认尝试刷新标识？" || return 0
    timer_start

    local old_id new_id
    old_id=$(settings get secure android_id 2>/dev/null)
    new_id=$(rand_hex 16)
    [ -z "$new_id" ] && new_id=$(date +%s | md5sum 2>/dev/null | head -c 16)
    if settings put secure android_id "$new_id" 2>/dev/null; then
        cmp_line "Android ID" "$old_id" "$new_id"
    else
        echo "  ${R}✕ Android ID 无权限修改${RST}"
    fi

    if cmd adid reset 2>/dev/null; then
        cmp_line "广告 ID" "(旧)" "已请求重置"
    else
        echo "  ${GR}· 广告 ID：请到 设置 → Google → 广告 → 重置广告 ID${RST}"
    fi

    local old_bt new_bt
    old_bt=$(settings get secure bluetooth_address 2>/dev/null)
    new_bt=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | sed 's/-//g;s/../&:/g' | head -c 17 | tr 'a-z' 'A-Z')
    if [ -n "$new_bt" ] && settings put secure bluetooth_address "$new_bt" 2>/dev/null; then
        cmp_line "蓝牙 MAC" "$old_bt" "$new_bt"
    else
        echo "  ${GR}· 蓝牙 MAC 无法修改${RST}"
    fi

    echo ""
    line
    echo "  ${G}✓ 完成${RST}"
    timer_end
    line
    echo ""
}

# ============================================================
# ROOT：残留清理
# ============================================================
do_residual_root() {
    title
    echo "  ${Y}▸${RST} 残留清理"
    line
    echo ""
    confirm "确认执行残留清理？" || return 0
    timer_start

    echo "  ${C}[1/7]${RST} 系统临时"
    rm -rf /data/cache/* /cache/* /data/anr/* /data/tombstones/* 2>/dev/null
    rm -rf /data/system/dropbox/* /data/system/graphicsstats/* /data/system/package_cache/* 2>/dev/null
    find /data/local/tmp -mindepth 1 -maxdepth 1 ! -name '.lm_*' ! -name '.luomu_*' -exec rm -rf {} + 2>/dev/null
    echo "    ${G}✓${RST}"

    echo "  ${C}[2/7]${RST} ACE 标记"
    rm -rf /data/local/tmp/ace_* /data/local/tmp/*.mark /data/local/tmp/*.ban 2>/dev/null
    rm -rf /data/local/tmp/*risk* /data/local/tmp/*ace* /data/local/tmp/*turing* 2>/dev/null
    rm -rf /mnt/vendor/persist/data/*.dat /persist/data/*.dat 2>/dev/null
    echo "    ${G}✓${RST}"

    echo "  ${C}[3/7]${RST} 驱动/挂残留"
    local p
    for p in /dev/Bing /data/BingHPJY /data/BingPUBG /data/jz /data/jz.sh \
        /data/.gamepad_driver_installed /data/system/xydriver.ko \
        /data/system/liborangeinit.so /data/system/liboxmem.so \
        /data/local/tmp/gamepad_driver.so /data/gamepad_driver.so \
        /data/nh.ko /data/nh /data/nh2 /data/nh3 /data/nh4 /data/nh5 /data/nh6 \
        /data/HPX /data/system/HPX /data/HPY /data/system/HPY /dev/kt_tmp \
        /data/local/tmp/byyang /data/local/tmp/shizuku /sdcard/elgg \
        /storage/emulated/0/elgg /storage/emulated/0/MT2 \
        /storage/emulated/0/WechatXposed /storage/emulated/0/落叶配置 /storage/emulated/0/BY物资
    do
        [ -e "$p" ] && rm -rf "$p" 2>/dev/null
    done
    echo "    ${G}✓${RST}"

    echo "  ${C}[4/7]${RST} 检测工具缓存"
    local pkg base
    for pkg in me.garfieldhan.holmes com.zhenxi.hunter icu.nullptr.nativetest \
        com.byyoung.setting bin.mt.plus bin.mt.plus.canary bin.mt.termex \
        com.omarea.vtools io.github.vvb2060.mahoshojo icu.nullptr.applistdetector \
        com.byxiaorun.detector io.github.huskydg.memorydetector \
        com.OrangeEnvironment.Detector com.Longze.detector.pro2 \
        rikka.safetynetchecker io.github.vvb2060.keyattestation com.apocalua.run
    do
        rm -rf /data/data/"$pkg"/cache/* 2>/dev/null
        for base in /storage/emulated/0 /sdcard; do
            rm -rf "$base/Android/data/$pkg" "$base/Android/obb/$pkg" 2>/dev/null
        done
    done
    echo "    ${G}✓${RST}"

    echo "  ${C}[5/7]${RST} 可疑脚本"
    find /sdcard /storage/emulated/0 /data/local/tmp -type f \( -name "*.sh" -o -name "*.zip" \) 2>/dev/null | while read -r f; do
        case "$f" in
            */magisk*|*/ksu*|*/modules/*|*/adb/*|*落幕清理*) continue ;;
            /system/*|/vendor/*) continue ;;
        esac
        rm -f "$f" 2>/dev/null
    done
    echo "    ${G}✓${RST}"

    echo "  ${C}[6/7]${RST} 腾讯目录/日志"
    rm -rf /sdcard/tencent /storage/emulated/0/tencent /data/local/tmp/tencent 2>/dev/null
    dmesg -c >/dev/null 2>&1; logcat -c >/dev/null 2>&1
    echo "    ${G}✓${RST}"

    echo "  ${C}[7/7]${RST} 杂项"
    rm -rf /storage/emulated/0/Android/data/com.tencent.mobileqq/cache/share 2>/dev/null
    find /data/local/tmp -type f -name '*.log' -delete 2>/dev/null
    echo "    ${G}✓${RST}"

    echo ""
    line
    echo "  ${G}${BOLD}✓ 残留清理完成${RST}"
    timer_end
    line
    echo ""
}

# 无 ROOT：残留清理
do_residual_noroot() {
    title
    echo "  ${Y}▸${RST} [无Root] 残留清理"
    line
    echo ""
    confirm "确认执行残留清理？" || return 0
    timer_start

    local d
    echo "  ${C}…${RST} 公共目录"
    for d in \
        /sdcard/tencent /storage/emulated/0/tencent \
        /sdcard/elgg /storage/emulated/0/elgg \
        /sdcard/MT2 /storage/emulated/0/MT2 \
        /sdcard/WechatXposed /storage/emulated/0/WechatXposed \
        /storage/emulated/0/Download/WechatXposed \
        /sdcard/落叶配置 /storage/emulated/0/落叶配置 \
        /sdcard/BY物资 /storage/emulated/0/BY物资 \
        /storage/emulated/0/Android/data/com.tencent.mobileqq/cache/share
    do
        if [ -e "$d" ]; then
            rm -rf "$d" 2>/dev/null && echo "  ${G}✓${RST} $d"
        fi
    done

    echo "  ${C}…${RST} 检测器外部数据"
    local pkg base
    for pkg in me.garfieldhan.holmes com.zhenxi.hunter icu.nullptr.nativetest \
        bin.mt.plus bin.mt.plus.canary io.github.vvb2060.mahoshojo \
        icu.nullptr.applistdetector com.byxiaorun.detector \
        io.github.huskydg.memorydetector com.OrangeEnvironment.Detector \
        com.Longze.detector.pro2 rikka.safetynetchecker com.apocalua.run
    do
        for base in /sdcard /storage/emulated/0; do
            rm -rf "$base/Android/data/$pkg" "$base/Android/obb/$pkg" "$base/Android/media/$pkg" 2>/dev/null
        done
    done
    echo "  ${G}✓${RST} 检测器外部目录"

    echo "  ${C}…${RST} 可疑 sh/zip（仅 sdcard）"
    find /sdcard /storage/emulated/0 -maxdepth 3 -type f \( -name "*.sh" -o -name "*.zip" \) 2>/dev/null | while read -r f; do
        case "$f" in
            *落幕清理*|*Magisk*|*ksu*) continue ;;
        esac
        # 不删用户可能需要的大 zip，只删小脚本和可疑名
        case "$f" in
            *.sh) rm -f "$f" 2>/dev/null ;;
        esac
    done
    echo "  ${G}✓${RST}"

    echo ""
    line
    echo "  ${G}${BOLD}✓ 残留清理完成${RST}"
    timer_end
    line
    echo ""
}

# ============================================================
# 菜单
# ============================================================
menu_game_root() {
    while true; do
        title
        echo "  ${C}┌─ 游戏清理 [Root]${RST}"
        echo "  ${C}│${RST}"
        echo "  ${C}├─${RST} ${W}1${RST}  无畏契约"
        echo "  ${C}├─${RST} ${W}2${RST}  和平精英"
        echo "  ${C}│${RST}"
        echo "  ${C}└─${RST} ${W}0${RST}  返回"
        echo ""
        echo -n "  ${C}请选择 › ${RST}"
        read choice
        case "$choice" in
            1) do_clean_game_root codev; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            2) do_clean_game_root pubgmhd; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            0) return ;;
            *) sleep 0.4 ;;
        esac
    done
}

menu_game_noroot() {
    while true; do
        title
        echo "  ${Y}┌─ 游戏清理 [无Root]${RST}"
        echo "  ${Y}│${RST}"
        echo "  ${Y}├─${RST} ${W}1${RST}  无畏契约"
        echo "  ${Y}├─${RST} ${W}2${RST}  和平精英"
        echo "  ${Y}├─${RST} ${W}3${RST}  无畏契约 pm clear"
        echo "  ${Y}├─${RST} ${W}4${RST}  和平精英 pm clear"
        echo "  ${Y}│${RST}"
        echo "  ${Y}└─${RST} ${W}0${RST}  返回"
        echo ""
        echo -n "  ${Y}请选择 › ${RST}"
        read choice
        case "$choice" in
            1) do_clean_game_noroot codev; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            2) do_clean_game_noroot pubgmhd; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            3) do_pm_clear_noroot codev; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            4) do_pm_clear_noroot pubgmhd; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            0) return ;;
            *) sleep 0.4 ;;
        esac
    done
}



# ============================================================
# 春秋检测：词条查询 + 实用清理
# 文档：mingzun09/Chunqiu-Detector-Problem-solution
# ============================================================
CQ_DOC_URLS="
https://cdn.jsdelivr.net/gh/mingzun09/Chunqiu-Detector-Problem-solution@main/language/answer_zh.md
https://raw.githubusercontent.com/mingzun09/Chunqiu-Detector-Problem-solution/main/language/answer_zh.md
https://ghproxy.net/https://raw.githubusercontent.com/mingzun09/Chunqiu-Detector-Problem-solution/main/language/answer_zh.md
"
CQ_SITE="https://mingzun09.github.io/Chunqiu-Detector-Problem-solution/"
CQ_CACHE="/data/local/tmp/.luomu_cq_doc.md"
[ -w /data/local/tmp ] 2>/dev/null || CQ_CACHE="/sdcard/.luomu_cq_doc.md"

cq_cleanable_paths() {
    cat << 'EOF'
/data/local/tmp/resetprop
/data/local/tmp/android_server
/data/local/tmp/android_server64
/data/local/tmp/gdbserver
/data/local/tmp/yshell
/data/local/tmp/simpleHook
/data/local/tmp/mount_mask
/data/local/tmp/scriptTMP
/data/local/tmp/cleaner_starter
/data/local/tmp/luckys
/data/local/tmp/HyperCeiler
/data/local/tmp/Surfing_update
/data/local/tmp/DisabledAllGoogleServices
/data/local/tmp/horae_control.log
/data/local/tmp/encore_logo.png
/data/local/luckys
/data/local/stryker
/data/local/MIO
/data/nh.ko
/data/nh
/data/nh2
/data/nh3
/data/nh4
/data/nh5
/data/nh6
/data/HPX
/data/HPY
/data/system/HPX
/data/system/HPY
/data/system/xydriver.ko
/data/system/liboxmem.so
/data/system/liborangeinit.so
/data/system/AppRetention
/data/system/Freezer
/data/system/NoActive
/data/system/junge
/data/BingHPJY
/data/BingPUBG
/data/js
/data/js.sh
/dev/Bing
/data/gpu_freq_table.conf
/data/swap_config.conf
/data/A内核.ini
/sdcard/fart
/sdcard/Download/dexdump
EOF
}

cq_fetch_doc() {
    local force="$1" body
    if [ "$force" != "1" ] && [ -s "$CQ_CACHE" ]; then
        local now mt age
        now=$(date +%s 2>/dev/null || echo 0)
        mt=$(stat -c %Y "$CQ_CACHE" 2>/dev/null || echo 0)
        age=$((now - mt))
        if [ "$age" -lt 604800 ] 2>/dev/null; then
            return 0
        fi
    fi
    echo "  ${C}…${RST} 拉取春秋文档"
    body=$(http_get_first "$CQ_DOC_URLS")
    if [ -z "$body" ]; then
        echo "  ${Y}!${RST} 无法下载"
        [ -s "$CQ_CACHE" ] && echo "  ${GR}使用本地缓存${RST}" && return 0
        return 1
    fi
    printf '%s\n' "$body" > "$CQ_CACHE"
    echo "  ${G}✓${RST} 已更新缓存"
    return 0
}

# 在文档中按 <details><summary><b>标题</b> 块检索，输出标题/原因/解决
cq_search() {
    local kw="$1"
    [ -z "$kw" ] && return 1
    cq_fetch_doc || return 1
    [ -s "$CQ_CACHE" ] || return 1

    echo ""
    echo "  ${C}搜索：${W}${kw}${RST}"
    line

    # awk：切分 details 块；标题、全文模糊匹配（去标签、空格）
    awk -v kw="$kw" '
    function strip(s,    t) {
      t=s
      gsub(/<[^>]+>/, "", t)
      gsub(/[*`#]+/, "", t)
      gsub(/\r/, "", t)
      return t
    }
    function norm(s,    t) {
      t=tolower(strip(s))
      gsub(/[ \t]+/, "", t)
      return t
    }
    BEGIN{
      nkw=norm(kw)
      hit=0
      block=""
      inb=0
    }
    {
      line=$0
      if (line ~ /<details>/) {
        inb=1
        block=line "\n"
        next
      }
      if (inb) {
        block=block line "\n"
        if (line ~ /<\/details>/) {
          inb=0
          title=""
          if (match(block, /<summary><b>[^<]+<\/b><\/summary>/)) {
            title=substr(block, RSTART, RLENGTH)
            gsub(/<\/?summary>|<\/?b>/, "", title)
          } else if (match(block, /<summary>[^<]*<b>[^<]+<\/b>[^<]*<\/summary>/)) {
            title=substr(block, RSTART, RLENGTH)
            gsub(/<[^>]+>/, "", title)
          }
          body=block
          gsub(/<details>|<\/details>|<summary>.*<\/summary>/, "", body)
          nt=norm(title)
          nb=norm(body)
          nall=nt nb
          # 匹配：完整关键词、或去掉空格后包含
          ok=0
          if (index(nall, nkw)>0) ok=1
          # 也允许原文大小写不敏感的空格保留匹配
          if (ok==0 && index(tolower(strip(title) strip(body)), tolower(kw))>0) ok=1
          if (ok==1 && hit<8) {
            hit++
            printf "  %s【词条 %d】%s%s\n", "'"${W}"'", hit, title, "'"${RST}"'"
            # 原因 / 检测方式
            reason=""
            n=split(body, lines, "\n")
            mode=""
            for (i=1;i<=n;i++) {
              L=lines[i]
              Ls=strip(L)
              if (Ls ~ /^####?[ \t]*检测方式/ || Ls ~ /^检测方式/) { mode="detect"; continue }
              if (Ls ~ /^####?[ \t]*异常原因/ || Ls ~ /^####?[ \t]*原因/ || Ls ~ /^原因/ || Ls ~ /^常见原因/) { mode="reason"; continue }
              if (Ls ~ /^####?[ \t]*解决/ || Ls ~ /^解决办法/ || Ls ~ /^解决方案/ || Ls ~ /^排查与解决/) { mode="fix"; continue }
              if (Ls ~ /^####/) { mode=""; continue }
              if (mode=="detect" || mode=="reason") {
                if (length(Ls)>0) reason=reason Ls "\n"
              }
            }
            if (length(reason)==0) {
              # 取正文前几行非空作原因摘要
              c=0
              for (i=1;i<=n && c<4;i++) {
                Ls=strip(lines[i])
                if (length(Ls)<2) continue
                if (Ls ~ /^解决/) break
                reason=reason Ls "\n"
                c++
              }
            }
            printf "  %s原因/检测：%s\n", "'"${GR}"'", "'"${RST}"'"
            n2=split(reason, rl, "\n")
            shown=0
            for (i=1;i<=n2 && shown<6;i++) {
              if (length(rl[i])>0) { printf "    %s\n", rl[i]; shown++ }
            }
            if (shown==0) print "    (文档未单列原因，见下方解决)"
            # 解决
            fix=""
            mode=""
            for (i=1;i<=n;i++) {
              L=lines[i]
              Ls=strip(L)
              if (Ls ~ /^####?[ \t]*解决/ || Ls ~ /^解决办法/ || Ls ~ /^解决方案/ || Ls ~ /^排查与解决/) { mode="fix"; continue }
              if (Ls ~ /^####/) { if (mode=="fix") mode=""; continue }
              if (mode=="fix" && length(Ls)>0) fix=fix Ls "\n"
            }
            if (length(fix)==0) {
              # 无明确标题时，输出摘要尾部几行
              c=0
              for (i=n;i>=1 && c<3;i--) {
                Ls=strip(lines[i])
                if (length(Ls)<2) continue
                fix=Ls "\n" fix
                c++
              }
            }
            printf "  %s解决：%s\n", "'"${G}"'", "'"${RST}"'"
            n3=split(fix, fl, "\n")
            shown=0
            for (i=1;i<=n3 && shown<8;i++) {
              if (length(fl[i])>0) { printf "    %s\n", fl[i]; shown++ }
            }
            # 可删路径提示
            if (match(body, /\/[a-zA-Z0-9._\-\/]+/)) {
              # collect paths in body
            }
            print "  '"${GR}"'────────────────────────'"${RST}"'"
          }
        }
      }
    }
    END{
      if (hit==0) {
        print "  未在词条块中命中，尝试全文片段："
      }
    }
    ' "$CQ_CACHE"

    # 若 details 未命中，退回全文行匹配（兼容旧格式）
    if ! awk -v kw="$kw" 'BEGIN{nkw=tolower(kw)} index(tolower($0),nkw)>0{found=1; exit} END{exit !found}' "$CQ_CACHE"; then
        :
    fi

    # 补充：非 details 的全文行匹配（当上面 hit 可能为 0）
    awk -v kw="$kw" '
    BEGIN{ nkw=tolower(kw); gsub(/ /,"",nkw); c=0 }
    {
      raw=$0
      if (raw ~ /<details>/) next
      low=tolower(raw); gsub(/<[^>]+>/,"",low); gsub(/ /,"",low)
      if (index(low, nkw)>0) {
        gsub(/<[^>]+>/,"",raw)
        if (length(raw)>2 && c<12) { printf "  · %s\n", raw; c++ }
      }
    }
    END{ if(c==0) print "  (无更多全文片段)" }
    ' "$CQ_CACHE"

    line
    echo "  ${GR}完整文档: ${CQ_SITE}${RST}"
    echo ""
}

cq_scan_cleanable() {
    echo ""
    echo "  ${C}▸${RST} 扫描可清理路径"
    line
    local p found=0
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        if [ -e "$p" ]; then
            found=1
            [ -d "$p" ] && echo "  ${Y}[目录]${RST} $p" || echo "  ${Y}[文件]${RST} $p"
        fi
    done << EOF
$(cq_cleanable_paths)
EOF
    if [ -d /data/local/tmp ]; then
        for p in /data/local/tmp/*; do
            [ -e "$p" ] || continue
            case "$p" in
                *.mark|*.ban|*ace*|*frida*|*xposed*|*lspd*|*riru*|*magisk*|*ksu*)
                    echo "  ${Y}[可疑]${RST} $p"; found=1 ;;
            esac
        done
    fi
    [ "$found" = "0" ] && echo "  ${G}✓ 未发现列表内路径${RST}"
    line
    echo ""
}

cq_clean_one() {
    local p="$1"
    [ -z "$p" ] && return 1
    if [ ! -e "$p" ]; then
        echo "  ${GR}不存在：$p${RST}"
        return 1
    fi
    case "$p" in
        /|/system|/system/*|/vendor|/vendor/*|/proc|/proc/*|/data/adb|/data/adb/*)
            echo "  ${R}✕ 受保护路径，拒绝删除${RST}"; return 1 ;;
    esac
    case "$p" in
        /data/local/*|/data/nh*|/data/HP*|/data/Bing*|/data/js*|/data/system/HP*|/data/system/xy*|/data/system/libox*|/data/system/liborange*|/data/system/AppRetention*|/data/system/Freezer*|/data/system/NoActive*|/data/system/junge*|/data/gpu*|/data/swap*|/data/A内核*|/dev/Bing*|/sdcard/fart*|/sdcard/Download/dexdump*|/storage/emulated/*/fart*|/storage/emulated/*/Download/dexdump*)
            ;;
        *)
            echo "  ${R}✕ 不在可清理白名单${RST}"; return 1 ;;
    esac
    confirm "删除 $p ？" || return 1
    rm -rf "$p" 2>/dev/null
    [ -e "$p" ] && echo "  ${R}✕ 删除失败${RST}" || echo "  ${G}✓ 已删除${RST}"
}

cq_clean_all_found() {
    confirm "删除扫描到的白名单路径？" || return 0
    local p n=0
    while IFS= read -r p; do
        [ -z "$p" ] && continue
        [ -e "$p" ] || continue
        case "$p" in
            /data/local/*|/data/nh*|/data/HP*|/data/Bing*|/data/js*|/data/system/HP*|/data/system/xy*|/data/system/libox*|/data/system/liborange*|/data/system/AppRetention*|/data/system/Freezer*|/data/system/NoActive*|/data/system/junge*|/data/gpu*|/data/swap*|/data/A内核*|/dev/Bing*|/sdcard/fart*|/sdcard/Download/dexdump*)
                rm -rf "$p" 2>/dev/null && echo "  ${G}✓${RST} $p" && n=$((n+1))
                ;;
        esac
    done << EOF
$(cq_cleanable_paths)
EOF
    echo "  ${G}完成 ${n} 项${RST}"
    echo ""
}

menu_chunqiu() {
    while true; do
        title
        echo "  ${C}┌─ 春秋检测${RST}"
        echo "  ${C}│${RST}"
        echo "  ${C}├─${RST} ${W}1${RST}  搜索检测词条"
        echo "  ${C}├─${RST} ${W}2${RST}  扫描并清理异常路径"
        echo "  ${C}├─${RST} ${W}3${RST}  删除指定路径"
        echo "  ${C}├─${RST} ${W}4${RST}  刷新词条文档"
        echo "  ${C}│${RST}"
        echo "  ${C}└─${RST} ${W}0${RST}  返回"
        echo ""
        echo -n "  ${C}请选择 › ${RST}"
        read choice
        case "$choice" in
            1)
                echo -n "  ${C}输入词条关键词 › ${RST}"
                read kw
                cq_search "$kw"
                echo -n "  ${GR}回车返回…${RST}"; read _
                ;;
            2)
                cq_scan_cleanable
                cq_clean_all_found
                echo -n "  ${GR}回车返回…${RST}"; read _
                ;;
            3)
                echo -n "  ${C}输入完整路径 › ${RST}"
                read path
                cq_clean_one "$path"
                echo -n "  ${GR}回车返回…${RST}"; read _
                ;;
            4)
                cq_fetch_doc 1
                echo -n "  ${GR}回车返回…${RST}"; read _
                ;;
            0) return ;;
            *) sleep 0.3 ;;
        esac
    done
}


main_menu_root() {
    while true; do
        title
        show_device_info
        echo "  ${P}┌─ 主菜单 ${G}Root${RST}"
        echo "  ${P}│${RST}"
        echo "  ${P}├─${RST} ${W}1${RST}  游戏清理"
        echo "  ${P}├─${RST} ${W}2${RST}  设备标识刷新"
        echo "  ${P}├─${RST} ${W}3${RST}  残留清理"
        echo "  ${P}├─${RST} ${W}4${RST}  春秋检测"
        echo "  ${P}├─${RST} ${W}5${RST}  检查更新"
        echo "  ${P}│${RST}"
        echo "  ${P}└─${RST} ${W}0${RST}  退出"
        echo ""
        echo -n "  ${P}请选择 › ${RST}"
        read choice
        case "$choice" in
            1) menu_game_root ;;
            2) do_reset_identity_root; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            3) do_residual_root; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            4) menu_chunqiu ;;
            5) check_update; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            0) echo ""; echo "  ${G}落幕清理已退出${RST}"; echo ""; exit 0 ;;
            *) sleep 0.4 ;;
        esac
    done
}

main_menu_noroot() {
    while true; do
        title
        show_device_info
        echo "  ${Y}┌─ 主菜单 ${Y}无Root${RST}"
        echo "  ${Y}│${RST}"
        echo "  ${Y}├─${RST} ${W}1${RST}  游戏清理"
        echo "  ${Y}├─${RST} ${W}2${RST}  设备标识"
        echo "  ${Y}├─${RST} ${W}3${RST}  残留清理"
        echo "  ${Y}├─${RST} ${W}4${RST}  春秋检测"
        echo "  ${Y}├─${RST} ${W}5${RST}  检查更新"
        echo "  ${Y}│${RST}"
        echo "  ${Y}└─${RST} ${W}0${RST}  退出"
        echo ""
        echo -n "  ${Y}请选择 › ${RST}"
        read choice
        case "$choice" in
            1) menu_game_noroot ;;
            2) do_reset_identity_noroot; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            3) do_residual_noroot; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            4) menu_chunqiu ;;
            5) check_update; echo -n "  ${GR}回车返回…${RST}"; read _ ;;
            0) echo ""; echo "  ${G}落幕清理已退出${RST}"; echo ""; exit 0 ;;
            *) sleep 0.4 ;;
        esac
    done
}

# ============================================================
# 入口
# ============================================================
# 解析自身路径
case "$SCRIPT_PATH" in
    /*) ;;
    *) SCRIPT_PATH="$(pwd)/$SCRIPT_PATH" ;;
esac

report_usage
detect_root

case "$1" in
    codev)   [ "$IS_ROOT" = "1" ] && do_clean_game_root codev || do_clean_game_noroot codev; exit 0 ;;
    pubgmhd) [ "$IS_ROOT" = "1" ] && do_clean_game_root pubgmhd || do_clean_game_noroot pubgmhd; exit 0 ;;
    reset)   [ "$IS_ROOT" = "1" ] && do_reset_identity_root || do_reset_identity_noroot; exit 0 ;;
    residual)[ "$IS_ROOT" = "1" ] && do_residual_root || do_residual_noroot; exit 0 ;;
    update)  check_update; exit 0 ;;
esac

splash
check_update

if [ "$IS_ROOT" = "1" ]; then
    main_menu_root
else
    sleep 0.5
    main_menu_noroot
fi
