#!/system/bin/sh
# ============================================================
# 落幕清理
# 游戏清理 · 设备标识刷新 · 残留清理
# ============================================================

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

# ---------- 计时 ----------
_START_TS=0
timer_start() {
    _START_TS=$(date +%s 2>/dev/null)
    [ -z "$_START_TS" ] && _START_TS=0
}
timer_end() {
    local end now cost m s
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

# ---------- 开屏动画 ----------
splash() {
    clear
    echo ""
    echo ""
    printf "  ${P}"
    # 渐入标题
    local frames="
          ·
         · ·
        · 落 ·
       · 落幕 ·
      · 落幕清 ·
     · 落幕清理 ·
    "
    # 简单逐帧
    clear; echo ""; echo ""; echo "                    ${GR}·${RST}"; sleep 0.08
    clear; echo ""; echo ""; echo "                   ${GR}· ·${RST}"; sleep 0.08
    clear; echo ""; echo ""; echo "                  ${P}· 落 ·${RST}"; sleep 0.1
    clear; echo ""; echo ""; echo "                 ${P}· 落幕 ·${RST}"; sleep 0.1
    clear; echo ""; echo ""; echo "                ${P}· 落幕清 ·${RST}"; sleep 0.1
    clear; echo ""; echo ""
    echo "${P}  ╔══════════════════════════════════════╗${RST}"
    echo "${P}  ║${RST}                                      ${P}║${RST}"
    echo "${P}  ║${RST}          ${W}${BOLD}落  幕  清  理${RST}            ${P}║${RST}"
    echo "${P}  ║${RST}                                      ${P}║${RST}"
    echo "${P}  ║${RST}  ${GR}Game · Identity · Residual Clean${RST}   ${P}║${RST}"
    echo "${P}  ║${RST}                                      ${P}║${RST}"
    echo "${P}  ╚══════════════════════════════════════╝${RST}"
    sleep 0.25
    echo ""
    # 加载点
    printf "  ${GR}"
    local i
    for i in 1 2 3 4 5 6; do
        printf "▓"
        sleep 0.06
    done
    printf "${RST}"
    echo ""
    sleep 0.15
}

# ---------- 设备信息 ----------
show_device_info() {
    local model brand release sdk kernel abilist serial android_id spatch
    model=$(getprop ro.product.model 2>/dev/null)
    brand=$(getprop ro.product.brand 2>/dev/null)
    release=$(getprop ro.build.version.release 2>/dev/null)
    sdk=$(getprop ro.build.version.sdk 2>/dev/null)
    kernel=$(uname -r 2>/dev/null)
    serial=$(getprop ro.serialno 2>/dev/null)
    [ -z "$serial" ] && serial=$(getprop ro.boot.serialno 2>/dev/null)
    android_id=$(settings get secure android_id 2>/dev/null)
    spatch=$(getprop ro.build.version.security_patch 2>/dev/null)
    local market
    market=$(getprop ro.product.marketname 2>/dev/null)
    [ -z "$market" ] && market=$(getprop ro.product.odm.marketname 2>/dev/null)

    echo "  ${C}┌─ 设备信息${RST}"
    echo "  ${C}│${RST}"
    [ -n "$brand" ] && echo "  ${C}│${RST}  品牌    ${W}${brand}${RST}"
    [ -n "$model" ] && echo "  ${C}│${RST}  型号    ${W}${model}${RST}"
    [ -n "$market" ] && echo "  ${C}│${RST}  市场名  ${W}${market}${RST}"
    [ -n "$release" ] && echo "  ${C}│${RST}  系统    ${W}Android ${release}${RST} ${GR}(API ${sdk})${RST}"
    [ -n "$kernel" ] && echo "  ${C}│${RST}  内核    ${W}${kernel}${RST}"
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
    echo "${P}  ║${RST}  ${GR}Game · Identity · Residual Clean${RST}   ${P}║${RST}"
    echo "${P}  ╚══════════════════════════════════════╝${RST}"
    echo ""
}

# ---------- Root 检查 ----------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo ""
        echo "  ${R}✕ 需要 Root 权限${RST}"
        echo "  ${Y}请先执行 su 后再运行本脚本${RST}"
        echo ""
        exit 1
    fi
}

# ---------- 工具函数 ----------
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

# 对比输出：名称 / 旧值 / 新值
cmp_line() {
    local name="$1"
    local old="$2"
    local new="$3"
    # 截断过长
    local o n
    o="$old"
    n="$new"
    [ ${#o} -gt 22 ] && o="${o:0:20}.."
    [ ${#n} -gt 22 ] && n="${n:0:20}.."
    [ -z "$o" ] && o="(空)"
    [ -z "$n" ] && n="(空)"
    printf "  ${G}✓${RST} %-12s ${GR}%s${RST}\n" "$name" ""
    printf "      ${GR}旧${RST} %-22s ${C}→${RST} ${W}%s${RST}\n" "$o" "$n"
}

# ============================================================
# 游戏清理核心
# ============================================================
do_clean_game() {
    local key="$1"
    local pattern gname skip_db

    case "$key" in
        codev)
            pattern="tmgp.codev|codev|valorant"
            gname="无畏契约"
            skip_db=0
            ;;
        pubgmhd)
            pattern="pubgmhd|hpjy"
            gname="和平精英"
            skip_db=0
            ;;
        *)
            echo "  ${R}未知游戏${RST}"
            return 1
            ;;
    esac

    title
    echo "  ${C}▸${RST} 正在准备清理 ${W}${gname}${RST}"
    line
    echo ""
    timer_start

    local packages
    packages=$(pm list packages 2>/dev/null | grep -iE "$pattern" | cut -d: -f2)

    if [ -z "$packages" ]; then
        echo "  ${R}✕ 未检测到 ${gname}${RST}"
        echo "  ${GR}请确认游戏已安装${RST}"
        echo ""
        return 0
    fi

    echo "  ${G}✓${RST} 检测到包名："
    for p in $packages; do
        echo "    ${GR}·${RST} ${W}$p${RST}"
    done

    local users
    users=$(get_all_users)
    echo "  ${G}✓${RST} 用户空间：${GR}$users${RST}"
    echo ""

    echo -n "  ${C}…${RST} 停止游戏进程"
    for p in $packages; do
        am force-stop "$p" 2>/dev/null
    done
    echo "\r  ${G}✓${RST} 游戏进程已停止          "
    sleep 0.25
    echo ""

    local uid pkg data_dir
    for uid in $users; do
        for pkg in $packages; do
            echo "  ${Y}📂${RST} ${W}$pkg${RST} ${GR}(用户 $uid)${RST}"

            for data_dir in "/data/user/$uid/$pkg" "/data/user_de/$uid/$pkg"; do
                [ -d "$data_dir" ] || continue

                if [ -d "$data_dir/shared_prefs" ]; then
                    rm -rf "$data_dir/shared_prefs" 2>/dev/null
                    echo "    ${G}✓${RST} shared_prefs"
                fi

                if [ -d "$data_dir/cache" ]; then
                    rm -rf "$data_dir/cache"/* 2>/dev/null
                    echo "    ${G}✓${RST} cache"
                fi

                rm -rf "$data_dir/code_cache" "$data_dir/no_backup" 2>/dev/null

                if [ "$skip_db" != "1" ]; then
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
                            "$data_dir/files/tbs" \
                            "$data_dir/files/ace" \
                            "$data_dir/files/ACE" \
                            "$data_dir/files/anticheat" \
                            "$data_dir/files/turing" \
                            "$data_dir/files/app_turingdfp" \
                            "$data_dir/files/beacon" \
                            "$data_dir/files/ano_tmp" \
                            "$data_dir/files/perfsight" 2>/dev/null

                        find "$data_dir/files" -type f -size -1M -exec rm -f {} \; 2>/dev/null
                        echo "    ${G}✓${RST} files 标记与小文件"
                    fi
                fi
            done

            local bases
            if [ "$uid" = "0" ]; then
                bases="/sdcard /storage/emulated/0"
            else
                bases="/storage/emulated/$uid /mnt/user/$uid/emulated/0 /data/media/$uid"
            fi

            local base sub ext
            for base in $bases; do
                for sub in data obb; do
                    ext="$base/Android/$sub/$pkg"
                    [ -d "$ext" ] || continue
                    rm -rf "$ext/cache"/* 2>/dev/null
                    [ "$skip_db" != "1" ] && find "$ext" -type f -size -1M -exec rm -f {} \; 2>/dev/null
                    echo "    ${G}✓${RST} 外部 $sub 缓存"
                done
            done

            rm -f /data/dalvik-cache/*"$pkg"* 2>/dev/null
            rm -f /data/dalvik-cache/arm/*"$pkg"* 2>/dev/null
            rm -f /data/dalvik-cache/arm64/*"$pkg"* 2>/dev/null
            rm -f /data/system/package_cache/*"$pkg"* 2>/dev/null
            echo ""
        done
    done

    rm -rf /data/local/tmp/ace_*.mark /data/local/tmp/*.ban 2>/dev/null
    rm -rf /data/system/dropbox/* /data/tombstones/* /data/anr/* 2>/dev/null

    line
    echo "  ${G}${BOLD}✓ ${gname} 清理完成${RST}"
    timer_end
    echo "  ${Y}建议手动重启游戏后再进入${RST}"
    line
    echo ""
}

# ============================================================
# 设备标识刷新（带属性对比）
# ============================================================
do_reset_identity() {
    title
    echo "  ${P}▸${RST} 正在刷新设备标识"
    echo "  ${GR}格式：旧值  →  新值${RST}"
    line
    echo ""
    timer_start

    local rp users
    rp=$(find_resetprop)
    users=$(get_all_users)

    # 1. Android ID
    local old_id new_id
    old_id=$(settings get secure android_id 2>/dev/null)
    new_id=$(rand_hex 16)
    [ -z "$new_id" ] && new_id=$(date +%s | md5sum 2>/dev/null | head -c 16)
    settings put secure android_id "$new_id" 2>/dev/null
    cmp_line "Android ID" "$old_id" "$new_id"
    sleep 0.1

    # 2. 广告 ID
    local old_adid="(系统管理)"
    pm clear com.google.android.gms >/dev/null 2>&1
    pm clear com.google.android.gsf >/dev/null 2>&1
    cmd adid reset 2>/dev/null
    rm -rf /data/data/com.google.android.gms/cache/* 2>/dev/null
    rm -rf /data/data/com.google.android.gms/shared_prefs/adid.xml 2>/dev/null
    cmp_line "广告 ID" "$old_adid" "已重置"
    sleep 0.1

    # 3. SSAID
    local uid
    for uid in $users; do
        rm -f "/data/system/users/$uid/settings_ssaid.xml" 2>/dev/null
    done
    cmp_line "SSAID" "(已存在)" "已清除"
    sleep 0.1

    # 4. 序列号
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
    echo "$new_serial" > "$tmp_serial"
    chmod 644 "$tmp_serial" 2>/dev/null
    local old_enf
    old_enf=$(getenforce 2>/dev/null)
    setenforce 0 2>/dev/null

    local serial_ok=0 path
    for path in \
        /sys/devices/soc0/serial_number \
        /sys/devices/platform/soc/serial_number \
        /sys/class/android_usb/android0/iSerial \
        /sys/class/android_usb/android0/f_serial \
        /sys/devices/virtual/android_usb/android0/iSerial
    do
        [ -e "$path" ] || continue
        mount | grep -q "$path" && umount "$path" 2>/dev/null
        mount --bind "$tmp_serial" "$path" 2>/dev/null && serial_ok=$((serial_ok+1))
    done
    [ "$old_enf" = "Enforcing" ] && setenforce 1 2>/dev/null

    if [ $serial_ok -gt 0 ]; then
        cmp_line "序列号" "$old_serial" "$new_serial ($serial_ok路径)"
    else
        cmp_line "序列号" "$old_serial" "$new_serial"
    fi
    sleep 0.1

    # 5. WiFi MAC
    local wlan old_mac new_mac
    wlan=$(ip link 2>/dev/null | grep -oE 'wlan[0-9]+' | head -1)
    if [ -n "$wlan" ]; then
        old_mac=$(ip link show "$wlan" 2>/dev/null | grep -oE 'link/ether [0-9a-f:]+' | awk '{print $2}')
        new_mac=$(rand_hex 10 | sed 's/../&:/g;s/:$//')
        [ -z "$new_mac" ] && new_mac="00:00:$(date +%s | tail -c 7 | sed 's/../&:/g;s/:$//')"
        ip link set "$wlan" address "02:$new_mac" 2>/dev/null
        cmp_line "WiFi MAC" "$old_mac" "02:$new_mac"
    else
        cmp_line "WiFi MAC" "(无接口)" "跳过"
    fi
    sleep 0.1

    # 6. 蓝牙 MAC
    local old_bt new_bt
    old_bt=$(settings get secure bluetooth_address 2>/dev/null)
    new_bt=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | sed 's/-//g;s/../&:/g' | head -c 17 | tr 'a-z' 'A-Z')
    [ -z "$new_bt" ] && new_bt="02:00:00:00:00:01"
    settings put secure bluetooth_address "$new_bt" 2>/dev/null
    cmp_line "蓝牙 MAC" "$old_bt" "$new_bt"
    sleep 0.1

    # 7. OAID
    local old_oaid new_oaid
    old_oaid=$(cat /data/system/oaid_persistence_0 2>/dev/null)
    new_oaid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 16)
    [ -z "$new_oaid" ] && new_oaid=$(rand_hex 16)
    echo "$new_oaid" > /data/system/oaid_persistence_0 2>/dev/null
    cmp_line "OAID" "$old_oaid" "$new_oaid"
    sleep 0.1

    # 8. VAID
    local old_vaid new_vaid
    old_vaid=$(cat /data/system/vaid_persistence_platform 2>/dev/null)
    new_vaid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 16)
    [ -z "$new_vaid" ] && new_vaid=$(rand_hex 16)
    echo "$new_vaid" > /data/system/vaid_persistence_platform 2>/dev/null
    cmp_line "VAID" "$old_vaid" "$new_vaid"
    sleep 0.1

    # 9. UUID
    local old_uuid new_uuid
    old_uuid=$(settings get global extm_uuid 2>/dev/null)
    new_uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    [ -z "$new_uuid" ] && new_uuid="$(date +%s)-$(rand_hex 8)"
    settings put global extm_uuid "$new_uuid" 2>/dev/null
    settings put system key_mqs_uuid "$new_uuid" 2>/dev/null
    settings put global gcbooster_uuid "$new_uuid" 2>/dev/null
    cmp_line "UUID" "$old_uuid" "$new_uuid"
    sleep 0.1

    # 10. IMEI / MEID
    if [ -n "$rp" ]; then
        local prop old_imei sample_old="" sample_new=""
        for prop in $(getprop 2>/dev/null | grep -i imei | awk -F '[][]' '{print $2}'); do
            old_imei=$(getprop "$prop")
            if [ ${#old_imei} -ge 14 ]; then
                [ -z "$sample_old" ] && sample_old="$old_imei"
                sample_new="86$((RANDOM % 80000 + 10000))00000000"
                $rp -f -n "$prop" "$sample_new" 2>/dev/null
            fi
        done
        $rp -f -n ro.ril.oem.meid "9900$((RANDOM % 8000000000 + 1000000000))" 2>/dev/null
        if [ -n "$sample_old" ]; then
            cmp_line "IMEI" "$sample_old" "$sample_new"
        else
            cmp_line "IMEI/MEID" "(无/已隐藏)" "属性已随机"
        fi
    else
        cmp_line "IMEI/MEID" "(无resetprop)" "跳过"
    fi
    sleep 0.1

    # 11. 日志
    dmesg -c >/dev/null 2>&1
    logcat -c >/dev/null 2>&1
    cmp_line "系统日志" "(旧日志)" "已清空"

    echo ""
    line
    echo "  ${G}${BOLD}✓ 设备标识刷新完成${RST}"
    timer_end
    echo "  ${Y}强烈建议重启手机后再打开游戏${RST}"
    line
    echo ""
}

# ============================================================
# 残留清理
# ============================================================
do_residual_clean() {
    title
    echo "  ${Y}▸${RST} 正在执行全面残留清理"
    echo "  ${GR}缓存 · 标记 · 驱动 · 检测工具 · 临时文件${RST}"
    line
    echo ""
    timer_start

    # 1
    echo "  ${C}[1/7]${RST} 系统临时与缓存"
    rm -rf /data/cache/* 2>/dev/null
    rm -rf /cache/* 2>/dev/null
    rm -rf /data/anr/* 2>/dev/null
    rm -rf /data/tombstones/* 2>/dev/null
    rm -rf /data/system/dropbox/* 2>/dev/null
    rm -rf /data/system/graphicsstats/* 2>/dev/null
    rm -rf /data/system/package_cache/* 2>/dev/null
    rm -rf /data/misc/iopgp 2>/dev/null
    find /data/local/tmp -mindepth 1 -maxdepth 1 ! -name '.lm_*' -exec rm -rf {} + 2>/dev/null
    echo "    ${G}✓${RST} anr / tombstones / dropbox / cache / tmp"
    sleep 0.08

    # 2
    echo "  ${C}[2/7]${RST} ACE / 风险标记"
    rm -rf /data/local/tmp/ace_* 2>/dev/null
    rm -rf /data/local/tmp/*.mark 2>/dev/null
    rm -rf /data/local/tmp/*.ban 2>/dev/null
    rm -rf /data/local/tmp/*risk* 2>/dev/null
    rm -rf /data/local/tmp/*ace* 2>/dev/null
    rm -rf /data/local/tmp/*turing* 2>/dev/null
    rm -rf /data/local/tmp/*qimei* 2>/dev/null
    rm -rf /data/local/tmp/*beacon* 2>/dev/null
    rm -rf /mnt/vendor/persist/data/*.dat 2>/dev/null
    rm -rf /mnt/vendor/persist/data/*.id 2>/dev/null
    rm -rf /persist/data/*.dat 2>/dev/null
    echo "    ${G}✓${RST} ace / mark / ban / persist 标记"
    sleep 0.08

    # 3
    echo "  ${C}[3/7]${RST} 驱动 · 内核 · 开挂残留"
    local paths="
/dev/Bing
/data/BingHPJY
/data/BingPUBG
/data/jz
/data/jz.sh
/data/.gamepad_driver_installed
/data/system/xydriver.ko
/data/system/liborangeinit.so
/data/system/liboxmem.so
/data/local/tmp/gamepad_driver.so
/data/gamepad_driver.so
/data/nh.ko
/data/nh
/data/nh2
/data/nh3
/data/nh4
/data/nh5
/data/nh6
/data/HPX
/data/system/HPX
/data/HPY
/data/system/HPY
/dev/kt_tmp
/data/property
/data/local/tmp/byyang
/data/local/tmp/shizuku
/data/local/tmp/shizuku_starter
/sdcard/elgg
/storage/emulated/0/elgg
/storage/emulated/0/MT2
/storage/emulated/0/WechatXposed
/storage/emulated/0/Download/WechatXposed
/storage/emulated/0/落叶配置
/storage/emulated/0/BY物资
"
    local p
    for p in $paths; do
        [ -e "$p" ] && rm -rf "$p" 2>/dev/null
    done
    find /data/local/tmp /data/system /data -maxdepth 2 \( \
        -name '*gamepad*' -o -name '*driver*.so' -o -name '*driver*.ko' \
        -o -name 'nh*.ko' -o -name '*xposed*' -o -name '*frida*' \
    \) -type f -exec rm -f {} \; 2>/dev/null
    echo "    ${G}✓${RST} 驱动 / 挂相关路径已清理"
    sleep 0.08

    # 4
    echo "  ${C}[4/7]${RST} 检测工具 · Root 工具缓存"
    local apps="
me.garfieldhan.holmes
com.zhenxi.hunter
icu.nullptr.nativetest
com.byyoung.setting
bin.mt.plus
bin.mt.plus.canary
bin.mt.termex
com.omarea.vtools
moe.shizuku.privileged.api
io.github.vvb2060.mahoshojo
icu.nullptr.applistdetector
com.byxiaorun.detector
io.github.huskydg.memorydetector
com.OrangeEnvironment.Detector
com.Longze.detector.pro2
rikka.safetynetchecker
io.github.vvb2060.keyattestation
com.apocalua.run
io.github.huskydg.magisk
com.topjohnwu.magisk
me.weishu.kernelsu
"
    local pkg base
    for pkg in $apps; do
        rm -rf /data/data/"$pkg"/cache/* 2>/dev/null
        for base in /storage/emulated/0 /storage/emulated/* /sdcard; do
            rm -rf "$base/Android/data/$pkg" 2>/dev/null
            rm -rf "$base/Android/obb/$pkg" 2>/dev/null
            rm -rf "$base/Android/media/$pkg" 2>/dev/null
        done
    done
    rm -rf /storage/emulated/0/MT2 /sdcard/MT2 2>/dev/null
    echo "    ${G}✓${RST} 检测器 / MT / 面具相关缓存"
    sleep 0.08

    # 5
    echo "  ${C}[5/7]${RST} 可疑 .sh / .zip 残留"
    local scan_dirs="/sdcard /storage/emulated/0 /data/local/tmp"
    local f skip
    for dir in $scan_dirs; do
        [ -d "$dir" ] || continue
        find "$dir" -type f \( -name "*.sh" -o -name "*.zip" \) 2>/dev/null | while read -r f; do
            skip=0
            case "$f" in
                */magisk*|*/ksu*|*/.magisk*|*/modules/*|*/adb/*) skip=1 ;;
                */落幕清理.sh) skip=1 ;;
            esac
            [ "$skip" = "1" ] && continue
            case "$f" in
                /system/*|/vendor/*|/product/*) continue ;;
            esac
            rm -f "$f" 2>/dev/null
        done
    done
    echo "    ${G}✓${RST} 扫描并清理可疑脚本/压缩包"
    sleep 0.08

    # 6
    echo "  ${C}[6/7]${RST} 腾讯通用目录 · 日志"
    rm -rf /sdcard/tencent /storage/emulated/0/tencent 2>/dev/null
    rm -rf /data/local/tmp/tencent /data/system/tencent 2>/dev/null
    local u
    for u in $(get_all_users); do
        rm -rf /data/user/$u/tencent 2>/dev/null
        rm -rf /data/user_de/$u/tencent 2>/dev/null
    done
    dmesg -c >/dev/null 2>&1
    logcat -c >/dev/null 2>&1
    echo "    ${G}✓${RST} tencent 目录与系统日志"
    sleep 0.08

    # 7
    echo "  ${C}[7/7]${RST} 其他常见残留"
    rm -rf /storage/emulated/0/Android/data/com.tencent.mobileqq/cache/share 2>/dev/null
    rm -rf /data/user/*/com.juom 2>/dev/null
    rm -rf /data/dalvik-cache/tmp 2>/dev/null
    find /data/local/tmp -type f -name '*.log' -delete 2>/dev/null
    find /data/local/tmp -type f -name '*.txt' -size -50k -delete 2>/dev/null
    echo "    ${G}✓${RST} 杂项残留"

    echo ""
    line
    echo "  ${G}${BOLD}✓ 残留清理完成${RST}"
    timer_end
    echo "  ${GR}已覆盖：系统缓存 · ACE标记 · 驱动/挂残留 · 检测工具 · 可疑脚本 · 腾讯目录${RST}"
    line
    echo ""
}

# ============================================================
# 子菜单：游戏清理
# ============================================================
menu_game() {
    while true; do
        title
        echo "  ${C}┌─ 游戏清理${RST}"
        echo "  ${C}│${RST}"
        echo "  ${C}├─${RST} ${W}1${RST}  无畏契约清理"
        echo "  ${C}├─${RST} ${W}2${RST}  和平精英清理"
        echo "  ${C}│${RST}"
        echo "  ${C}└─${RST} ${W}0${RST}  返回上级"
        echo ""
        echo -n "  ${C}请选择 › ${RST}"
        read choice
        case "$choice" in
            1)
                do_clean_game "codev"
                echo -n "  ${GR}按回车返回…${RST}"
                read _
                ;;
            2)
                do_clean_game "pubgmhd"
                echo -n "  ${GR}按回车返回…${RST}"
                read _
                ;;
            0) return ;;
            *)
                echo "  ${R}无效选项${RST}"
                sleep 0.5
                ;;
        esac
    done
}

# ============================================================
# 主菜单（带设备信息）
# ============================================================
main_menu() {
    while true; do
        title
        show_device_info
        echo "  ${P}┌─ 主菜单${RST}"
        echo "  ${P}│${RST}"
        echo "  ${P}├─${RST} ${W}1${RST}  游戏清理"
        echo "  ${P}│${RST}     ${GR}无畏契约 · 和平精英${RST}"
        echo "  ${P}│${RST}"
        echo "  ${P}├─${RST} ${W}2${RST}  设备标识刷新"
        echo "  ${P}│${RST}     ${GR}旧值 → 新值 对比显示${RST}"
        echo "  ${P}│${RST}"
        echo "  ${P}├─${RST} ${W}3${RST}  残留清理"
        echo "  ${P}│${RST}     ${GR}缓存 · 标记 · 驱动 · 检测工具${RST}"
        echo "  ${P}│${RST}"
        echo "  ${P}└─${RST} ${W}0${RST}  退出"
        echo ""
        echo -n "  ${P}请选择 › ${RST}"
        read choice
        case "$choice" in
            1) menu_game ;;
            2)
                do_reset_identity
                echo -n "  ${GR}按回车返回…${RST}"
                read _
                ;;
            3)
                do_residual_clean
                echo -n "  ${GR}按回车返回…${RST}"
                read _
                ;;
            0)
                echo ""
                echo "  ${G}落幕清理已退出${RST}"
                echo ""
                exit 0
                ;;
            *)
                echo "  ${R}无效选项${RST}"
                sleep 0.5
                ;;
        esac
    done
}

# ============================================================
# 入口
# ============================================================
check_root

case "$1" in
    codev|valorant)
        do_clean_game "codev"
        exit 0
        ;;
    pubgmhd|hpjy|pubg)
        do_clean_game "pubgmhd"
        exit 0
        ;;
    reset|identity)
        do_reset_identity
        exit 0
        ;;
    residual|clean)
        do_residual_clean
        exit 0
        ;;
esac

# 正常进入：开屏动画 → 主菜单
splash
main_menu
