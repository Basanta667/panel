#!/bin/bash
# =====================================================================
#  SMART BACKUP MANAGER v16  (Pterodactyl + Blueprint + Wings + Cloudflared)
# =====================================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---------- SETTINGS (yahan se badal sakte hain) ----------
REMOTE_NAME="blomp_cloud"
CONFIG_FILE="/root/.fakecloud_blomp"
NAME_FILE="/root/.fakecloud_backup_name"
BACKUP_FOLDER="BackupVps"
KEEP_COUNT=3          # cloud par kitne latest backup rakhne hain (1 risky hai)
INTERVAL_MIN=15       # auto-backup har kitne minute
STOP_WINGS=0          # 1 = backup ke time wings stop hogi (default: nahi)
PHP_VER="8.3"
STAGING="/var/backup_staging"   # SQL dump / token / manifest yahan banta hai (tar me jata hai)
WORK_DIR="/var/backup_work"     # temp .tar.gz yahan banta hai (tmpfs /tmp se bachne ke liye)
LOG="/var/log/fakecloud-backup.log"
WORKER="/root/do_full_backup.sh"
# Alag rclone config: aapke doosre rclone remotes overwrite nahi honge
export RCLONE_CONFIG="/root/.config/rclone/fakecloud.conf"
RCLONE_FLAGS=(--no-check-certificate --retries 5 --timeout 60m --contimeout 60s)
export DEBIAN_FRONTEND=noninteractive
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ye script ROOT user se run karein.${NC}"
    exit 1
fi
mkdir -p "$(dirname "$LOG")" "$WORK_DIR"

# ==================== NO-SYSTEMD SUPPORT ====================
# Container / PID1!=systemd par systemctl kaam nahi karta. Aise me ye shim
# systemctl calls ko `service` ya seedhe background process me badal deta hai.
HAS_SYSTEMD=0
[ -d /run/systemd/system ] && HAS_SYSTEMD=1

if [ "$HAS_SYSTEMD" -eq 0 ]; then
_cf_token() {
    local t=""
    [ -s /etc/cloudflared/token ] && t=$(tr -d '\r\n' < /etc/cloudflared/token)
    if [ -z "$t" ] && [ -f /etc/systemd/system/cloudflared.service ]; then
        t=$(grep -oE 'token [A-Za-z0-9=_.-]+' /etc/systemd/system/cloudflared.service | head -1 | awk '{print $NF}')
    fi
    echo "$t"
}
_bg() { local lg="$1"; shift; setsid nohup "$@" >>"$lg" 2>&1 < /dev/null & }

_nosysd() {
    local act="$1" u="$2" t
    case "$u" in
        cloudflared)
            case "$act" in
                start)   pgrep -f 'cloudflared.*tunnel' >/dev/null && return 0
                         t=$(_cf_token); [ -z "$t" ] && return 1
                         _bg /var/log/cloudflared.log cloudflared tunnel --no-autoupdate run --token "$t"; sleep 2 ;;
                stop)    pkill -f 'cloudflared.*tunnel'; return 0 ;;
                restart) _nosysd stop cloudflared; sleep 1; _nosysd start cloudflared ;;
            esac ;;
        wings)
            case "$act" in
                start)   [ -x /usr/local/bin/wings ] || return 1
                         pgrep -x wings >/dev/null && return 0
                         ( cd /etc/pterodactyl 2>/dev/null && _bg /var/log/wings.log /usr/local/bin/wings ); sleep 2 ;;
                stop)    pkill -x wings; return 0 ;;
                restart) _nosysd stop wings; sleep 1; _nosysd start wings ;;
            esac ;;
        pteroq)
            case "$act" in
                start)   pgrep -f 'artisan queue:work' >/dev/null && return 0
                         _bg /var/log/pteroq.log runuser -u www-data -- php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3 ;;
                stop)    pkill -f 'artisan queue:work'; return 0 ;;
                restart) _nosysd stop pteroq; sleep 1; _nosysd start pteroq ;;
            esac ;;
        tailscaled)
            case "$act" in
                start)   pgrep -x tailscaled >/dev/null && return 0
                         _bg /var/log/tailscaled.log tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking ;;
                stop)    pkill -x tailscaled; return 0 ;;
                restart) _nosysd stop tailscaled; sleep 1; _nosysd start tailscaled ;;
            esac ;;
        mysql|mariadb)
            mkdir -p /var/run/mysqld; chown mysql:mysql /var/run/mysqld 2>/dev/null
            service "$u" "$act" >/dev/null 2>&1 ;;
        *)  service "$u" "$act" >/dev/null 2>&1 ;;
    esac
}

_nosysd_active() {
    case "$1" in
        cloudflared) pgrep -f 'cloudflared.*tunnel' >/dev/null ;;
        wings)       pgrep -x wings >/dev/null ;;
        pteroq)      pgrep -f 'artisan queue:work' >/dev/null ;;
        tailscaled)  pgrep -x tailscaled >/dev/null ;;
        mysql|mariadb) mysqladmin ping --silent >/dev/null 2>&1 ;;
        *)           service "$1" status >/dev/null 2>&1 ;;
    esac
}

systemctl() {
    local now=0 cmd="" units=() a u rc=0
    for a in "$@"; do
        case "$a" in
            --now) now=1 ;;
            -*) ;;
            *) if [ -z "$cmd" ]; then cmd="$a"; else units+=("$a"); fi ;;
        esac
    done
    case "$cmd" in
        start|stop|restart)
            for u in "${units[@]}"; do _nosysd "$cmd" "$u" || rc=1; done; return $rc ;;
        enable)
            if [ $now -eq 1 ]; then for u in "${units[@]}"; do _nosysd start "$u"; done; fi
            return 0 ;;
        is-active) _nosysd_active "${units[0]}"; return $? ;;
        list-unit-files)
            { ls /etc/systemd/system/*.service /lib/systemd/system/*.service 2>/dev/null | xargs -r -n1 basename
              ls /etc/init.d 2>/dev/null | sed 's/$/.service/'; } | sort -u | sed 's/$/ enabled/' ;;
        *) return 0 ;;   # daemon-reload, disable, etc.
    esac
}
fi

# ==================== BASIC HELPERS ====================
say()    { echo -e "$@"; }
logmsg() { echo "$(date '+%F %T') $*" >> "$LOG"; }

load_blomp_config() {
    BLOMP_USER=""
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
}

load_backup_name() {
    if [ -f "$NAME_FILE" ]; then
        BACKUP_NAME=$(tr -cd 'A-Za-z0-9._-' < "$NAME_FILE")
    else
        BACKUP_NAME=""
    fi
}

save_backup_name() {
    local n
    n=$(echo "$1" | tr -cd 'A-Za-z0-9._-')
    [ -z "$n" ] && n="panel"
    echo "$n" > "$NAME_FILE"
    chmod 600 "$NAME_FILE"
    BACKUP_NAME="$n"
}

# .env se value nikalna
env_get() {
    grep -E "^$1=" /var/www/pterodactyl/.env 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d "\"'\r"
}

start_mysql() {
    mkdir -p /var/run/mysqld; chown mysql:mysql /var/run/mysqld 2>/dev/null
    systemctl start mysql >/dev/null 2>&1 || systemctl start mariadb >/dev/null 2>&1
}

wait_mysql() {
    local i
    for i in $(seq 1 30); do
        mysqladmin ping --silent >/dev/null 2>&1 && return 0
        sleep 1
    done
    return 1
}

# root socket se try, fail ho to debian.cnf se
mysql_root() {
    mysql "$@" 2>>"$LOG" || mysql --defaults-file=/etc/mysql/debian.cnf "$@" 2>>"$LOG"
}

# ==================== DEPENDENCIES ====================
ensure_rclone() {
    command -v rclone >/dev/null 2>&1 && return 0
    # official installer pehle (apt wala rclone purana hota hai)
    curl -fsSL https://rclone.org/install.sh | bash >>"$LOG" 2>&1 \
        || apt-get install -y rclone >>"$LOG" 2>&1
    command -v rclone >/dev/null 2>&1
}

install_all_dependencies() {
    clear
    say "${YELLOW}>>> Zaroori Tools Check & Setup...${NC}"
    local need=0 c
    for c in curl unzip flock pigz crontab tar; do
        command -v "$c" >/dev/null 2>&1 || need=1
    done
    if [ $need -eq 1 ]; then
        apt-get update -y >>"$LOG" 2>&1
        apt-get install -y curl tar gzip unzip coreutils util-linux ca-certificates cron pigz >>"$LOG" 2>&1 || true
        systemctl enable --now cron >/dev/null 2>&1 || true
    fi
    ensure_rclone || say "${RED}rclone install nahi hua! Log: $LOG${NC}"
    # NOTE: mariadb-client ko mysql-server ke upar install nahi karte (conflict se server hat sakta hai)
    if ! command -v mysqldump >/dev/null 2>&1; then
        apt-get install -y mysql-client >>"$LOG" 2>&1 || apt-get install -y mariadb-client >>"$LOG" 2>&1 || true
    fi
    mkdir -p /root/.config/rclone
    say "${GREEN}✓ All tools ready!${NC}"
    sleep 1
}

# ==================== BLOMP LOGIN ====================
setup_blomp() {
    clear
    say "${CYAN}======== BLOMP CLOUD LOGIN ========${NC}"
    ensure_rclone || return

    read -p "Blomp Email: " blomp_user
    read -s -p "Blomp Password: " blomp_pass
    echo ""
    echo ""

    if [ -z "$blomp_user" ] || [ -z "$blomp_pass" ]; then
        say "${RED}Email/Password empty nahi ho sakte.${NC}"
        sleep 2
        return
    fi

    say "${YELLOW}Blomp OpenStack Swift se connect ho raha hai...${NC}"
    mkdir -p "$(dirname "$RCLONE_CONFIG")"

    cat > "$RCLONE_CONFIG" <<EOF
[${REMOTE_NAME}]
type = swift
env_auth = false
user = ${blomp_user}
key = ${blomp_pass}
auth = https://authenticate.ain.net
tenant = storage
auth_version = 2
endpoint_type = public
use_segments_container = false
leave_parts_on_error = true
no_check_certificate = true
EOF
    chmod 600 "$RCLONE_CONFIG"
    unset blomp_pass

    cat > "$CONFIG_FILE" <<EOF
BLOMP_USER='${blomp_user}'
EOF
    chmod 600 "$CONFIG_FILE"

    if rclone lsf "${REMOTE_NAME}:${blomp_user}" "${RCLONE_FLAGS[@]}" >/tmp/blomp_test.log 2>&1; then
        say "${GREEN}✓ Blomp Login Successful!${NC}"
        say "Cloud Container: ${CYAN}${blomp_user}/${BACKUP_FOLDER}/${NC}"
    else
        say "${RED}✗ Login Fail!${NC}"
        cat /tmp/blomp_test.log 2>/dev/null
        rm -f "$CONFIG_FILE" "$RCLONE_CONFIG"
    fi
    rm -f /tmp/blomp_test.log
    read -p "Enter dabayein..." t
}

check_blomp_login() {
    load_blomp_config
    ensure_rclone || return 1
    if [ -z "$BLOMP_USER" ] || ! rclone listremotes 2>/dev/null | grep -q "^${REMOTE_NAME}:$"; then
        setup_blomp
        load_blomp_config
    fi
    [ -z "$BLOMP_USER" ] && return 1
    return 0
}

# ==================== CHECK IMPORTANT DATA ====================
show_important_data() {
    say "${CYAN}--- System / App / Database / Wings / Cloudflare Paths ---${NC}"
    local PATHS=(
        "/var/lib/mysql" "/var/lib/pterodactyl" "/etc/pterodactyl"
        "/var/www/pterodactyl" "/var/www/pterodactyl/.blueprint"
        "/var/lib/tailscale" "/etc/cloudflared" "/root/.cloudflared"
        "/etc/letsencrypt" "/etc/nginx" "/etc/php" "/etc/supervisor"
        "/root" "/home" "/etc/systemd/system" "/usr/local/bin"
    )
    local p sz
    for p in "${PATHS[@]}"; do
        if [ -e "$p" ]; then
            sz=$(du -sh "$p" 2>/dev/null | awk '{print $1}')
            say "  ${GREEN}FOUND${NC}  $p  →  ${YELLOW}$sz${NC}"
        else
            say "  ${RED}NOT FOUND${NC}  $p"
        fi
    done
    echo ""
    say "${CYAN}--- Last 15 log lines ---${NC}"
    tail -n 15 "$LOG" 2>/dev/null
    echo ""
}

# ==================== CLEANUP OLD BACKUPS ====================
cleanup_old_backups() {
    local dir="$1" keep="$2" all=() f i
    mapfile -t all < <(rclone lsf "$dir" --files-only --include "*.tar.gz" "${RCLONE_FLAGS[@]}" 2>>"$LOG" | sort -r)

    # Naya backup cloud par dikh raha ho tabhi purane delete karo
    if ! printf '%s\n' "${all[@]}" | grep -qxF "$keep"; then
        logmsg "CLEANUP SKIP: new file list me nahi dikha"
        return 0
    fi
    if [ "${#all[@]}" -le "$KEEP_COUNT" ]; then
        say "${GREEN}✓ Sirf ${#all[@]} backup(s) — cleanup zaroorat nahi.${NC}"
        return 0
    fi
    for i in "${!all[@]}"; do
        [ "$i" -lt "$KEEP_COUNT" ] && continue
        f="${all[$i]}"
        [ "$f" = "$keep" ] && continue
        say "${RED}DELETE OLD:${NC} $f"
        logmsg "DELETE OLD: $f"
        rclone deletefile "${dir}/${f}" "${RCLONE_FLAGS[@]}" 2>>"$LOG" || true
    done
    say "${GREEN}✓ Cleanup done — latest ${KEEP_COUNT} backup(s) rakhe gaye.${NC}"
}

# ==================== DATABASE DUMP (Layer 1) ====================
# Sab user databases ek dump me (system DBs ko chhod ke). Dump complete na ho to FAIL maana jayega.
_try_dump() {
    local out="$1"; shift
    local dbs=()
    mapfile -t dbs < <(mysql "$@" -N -e 'SHOW DATABASES' 2>>"$LOG" | grep -Ev '^(information_schema|performance_schema|mysql|sys)$')
    [ ${#dbs[@]} -eq 0 ] && return 1
    mysqldump "$@" --single-transaction --quick --routines --triggers --events \
        --databases "${dbs[@]}" > "$out" 2>>"$LOG"
    tail -n 3 "$out" 2>/dev/null | grep -q 'Dump completed'
}

create_database_dump() {
    local out="$STAGING/pterodactyl_database_dump.sql"
    mkdir -p "$STAGING"
    rm -f "$out"
    command -v mysqldump >/dev/null 2>&1 || return 1
    start_mysql
    sleep 1

    _try_dump "$out" && return 0
    if [ -f /etc/mysql/debian.cnf ]; then
        _try_dump "$out" --defaults-file=/etc/mysql/debian.cnf && return 0
    fi
    if [ -f /var/www/pterodactyl/.env ]; then
        local u p h
        u=$(env_get DB_USERNAME); p=$(env_get DB_PASSWORD); h=$(env_get DB_HOST)
        [ -z "$h" ] && h="127.0.0.1"
        if [ -n "$u" ]; then
            MYSQL_PWD="$p" _try_dump "$out" -h"$h" -u"$u" && return 0
        fi
    fi
    rm -f "$out"
    return 1
}

# ==================== BACKUP ENGINE ====================
backup_inner() {
    load_blomp_config
    load_backup_name
    if [ -z "$BACKUP_NAME" ] || [ -z "$BLOMP_USER" ]; then
        say "${RED}Pehle Login + Backup Name set karein.${NC}"
        return 1
    fi

    # log rotate (5MB se bada ho to last 2000 lines rakho)
    if [ -f "$LOG" ] && [ "$(stat -c%s "$LOG" 2>/dev/null || echo 0)" -gt 5242880 ]; then
        tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi

    local TIME FILE TEMP_FILE DEST_DIR DEST_OBJECT COMP TAR_RC UPLOAD_RC HUMAN avail_kb p
    TIME=$(date +%Y-%m-%d_%H-%M-%S)
    FILE="${BACKUP_NAME}_${TIME}.tar.gz"
    mkdir -p "$WORK_DIR"
    TEMP_FILE="${WORK_DIR}/${FILE}"
    DEST_DIR="${REMOTE_NAME}:${BLOMP_USER}/${BACKUP_FOLDER}/${BACKUP_NAME}"
    DEST_OBJECT="${DEST_DIR}/${FILE}"

    logmsg "=== BACKUP START file=$FILE ==="

    avail_kb=$(df -Pk "$WORK_DIR" | awk 'NR==2{print $4}')
    if [ "${avail_kb:-0}" -lt 1048576 ]; then
        say "${RED}✗ ${WORK_DIR} me 1GB se kam free space hai!${NC}"
        logmsg "ABORT: low disk space"
        return 1
    fi

    # ---- Staging (SQL dump + cloudflared token + manifest) ----
    rm -rf "$STAGING"; mkdir -p "$STAGING"; chmod 700 "$STAGING"

    say "${YELLOW}[1/4] Layer 1: Database SQL Dump...${NC}"
    if create_database_dump; then
        say "${GREEN}   ✓ SQL Dump Created: $(du -h "$STAGING/pterodactyl_database_dump.sql" | awk '{print $1}')${NC}"
    else
        say "${YELLOW}   ! SQL Dump fail — sirf Layer 2 (raw /var/lib/mysql) backup hoga.${NC}"
        logmsg "WARN: SQL dump failed"
    fi

    [ -f /etc/cloudflared/token ] && cp /etc/cloudflared/token "$STAGING/cloudflared_token_backup" 2>/dev/null

    local POSSIBLE_PATHS=(
        "/var/lib/mysql"            # Layer 2: raw DB files
        "/var/lib/pterodactyl"      # Game volumes
        "/etc/pterodactyl"          # Wings config
        "/var/www/pterodactyl"      # Panel + Blueprint + .env
        "/var/lib/tailscale" "/etc/tailscale" "/etc/default/tailscaled"
        "/etc/cloudflared" "/root/.cloudflared"
        "/etc/letsencrypt" "/etc/nginx" "/etc/apache2"
        "/etc/php" "/etc/mysql" "/etc/redis" "/etc/supervisor"
        "/root" "/home"
        "/etc/systemd/system" "/usr/local/bin"
        "/var/spool/cron" "/etc/crontab"
    )

    # Staging sabse pehle -> restore me manifest jaldi padh sakte hain
    local REL=("${STAGING#/}")
    {
        echo "created=$TIME"
        echo "name=$BACKUP_NAME"
        for p in "${POSSIBLE_PATHS[@]}"; do
            [ -e "$p" ] && echo "path=$p"
        done
        [ -s "$STAGING/pterodactyl_database_dump.sql" ] && echo "sqldump=yes"
    } > "$STAGING/manifest.txt"
    for p in "${POSSIBLE_PATHS[@]}"; do
        [ -e "$p" ] && REL+=("${p#/}")
    done

    if [ ${#REL[@]} -le 1 ]; then
        say "${RED}✗ Backup karne ke liye koi data nahi mila!${NC}"
        rm -rf "$STAGING"
        return 1
    fi

    say "${CYAN}[2/4] COMPRESSING ALL DATA...${NC}"
    say "  Cloud Folder: ${GREEN}${BACKUP_FOLDER}/${BACKUP_NAME}/${NC}"
    say "  Backup File:  ${GREEN}${FILE}${NC}"
    say "--------------------------------------------------------"

    local WINGS_STOPPED=0
    if [ "$STOP_WINGS" = "1" ] && systemctl is-active --quiet wings 2>/dev/null; then
        systemctl stop wings >/dev/null 2>&1 && WINGS_STOPPED=1
    fi

    local TAR_OPTS=(
        --ignore-failed-read
        --warning=no-file-changed
        --warning=no-file-removed
        --exclude="root/*.tar.gz"
        --exclude="root/.cache"
        --exclude="var/www/pterodactyl/node_modules"
        --exclude="var/lib/pterodactyl/backups"   # panel ke game-server backups (bade hote hain)
        --exclude="var/backup_work"
    )
    if command -v pigz >/dev/null 2>&1; then COMP="pigz"; else COMP="gzip"; fi

    tar -C / -cf - "${TAR_OPTS[@]}" "${REL[@]}" 2>>"$LOG" | "$COMP" -1 -c > "$TEMP_FILE" 2>>"$LOG"
    TAR_RC=${PIPESTATUS[0]}

    rm -rf "$STAGING"
    [ "$WINGS_STOPPED" = "1" ] && systemctl start wings >/dev/null 2>&1

    # tar exit 1 = "file changed while reading" (normal warning). 2+ = fatal.
    if [ "$TAR_RC" -gt 1 ] || [ ! -s "$TEMP_FILE" ]; then
        say "${RED}✗ Compression Fail (tar rc=$TAR_RC)! Log: $LOG${NC}"
        logmsg "FAIL: tar rc=$TAR_RC"
        rm -f "$TEMP_FILE"
        return 1
    fi
    if ! "$COMP" -t "$TEMP_FILE" 2>>"$LOG"; then
        say "${RED}✗ Archive corrupt nikla — upload cancel.${NC}"
        logmsg "FAIL: gzip test"
        rm -f "$TEMP_FILE"
        return 1
    fi

    HUMAN=$(du -h "$TEMP_FILE" | awk '{print $1}')
    say "${CYAN}[3/4] Backup Size: ${HUMAN}${NC}"
    say "${YELLOW}[4/4] Blomp Cloud par Upload ho raha hai...${NC}"

    if [ -t 1 ]; then
        rclone copyto "$TEMP_FILE" "$DEST_OBJECT" "${RCLONE_FLAGS[@]}" --progress
    else
        rclone copyto "$TEMP_FILE" "$DEST_OBJECT" "${RCLONE_FLAGS[@]}" >>"$LOG" 2>&1
    fi
    UPLOAD_RC=$?
    rm -f "$TEMP_FILE"

    say "--------------------------------------------------------"
    if [ $UPLOAD_RC -eq 0 ]; then
        say "${GREEN}✓ BACKUP SUCCESSFUL & UPLOADED!${NC}"
        logmsg "SUCCESS $FILE ($HUMAN)"
        cleanup_old_backups "$DEST_DIR" "$FILE"
        return 0
    else
        say "${RED}✗ Upload Failed (rc=$UPLOAD_RC). Log: $LOG${NC}"
        logmsg "FAIL: upload rc=$UPLOAD_RC"
        return 1
    fi
}

# Overlap rokne ke liye lock (cron + manual dono safe)
run_backup() {
    mkdir -p "$(dirname "$LOG")" "$WORK_DIR"
    (
        flock -n 9 || { say "${YELLOW}Dusra backup already chal raha hai — skip.${NC}"; logmsg "SKIP: lock busy"; exit 99; }
        backup_inner
    ) 9>/var/lock/fakecloud-backup.lock
}

# Cron worker ab isi script ke functions se bante hain (duplicate code nahi)
create_auto_worker() {
    {
        echo '#!/bin/bash'
        echo '# AUTO-GENERATED — option 1 se regenerate hota hai, edit mat karein'
        echo 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        declare -p GREEN CYAN RED YELLOW NC REMOTE_NAME CONFIG_FILE NAME_FILE BACKUP_FOLDER \
                   KEEP_COUNT STOP_WINGS STAGING WORK_DIR LOG RCLONE_CONFIG RCLONE_FLAGS
        declare -p HAS_SYSTEMD
        declare -f systemctl _nosysd _nosysd_active _bg _cf_token 2>/dev/null
        declare -f say logmsg load_blomp_config load_backup_name env_get start_mysql \
                   _try_dump create_database_dump cleanup_old_backups backup_inner run_backup
        echo 'export RCLONE_CONFIG'
        echo 'run_backup'
        echo 'exit $?'
    } > "$WORKER"
    chmod 700 "$WORKER"
}

# ==================== 1) AUTO BACKUP ====================
start_auto_backup() {
    clear
    if ! check_blomp_login; then sleep 2; return; fi
    command -v crontab >/dev/null 2>&1 || { apt-get install -y cron >>"$LOG" 2>&1; systemctl enable --now cron >/dev/null 2>&1; }

    say "${CYAN}╔════════════════════════════════════════════╗${NC}"
    say "${CYAN}║   SMART AUTO-BACKUP (har ${INTERVAL_MIN} minute)          ║${NC}"
    say "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    say "Cloud: ${YELLOW}${BACKUP_FOLDER}/[NAME]/${NC}   (latest ${KEEP_COUNT} backups rahenge)"
    echo ""

    load_backup_name
    local newname
    if [ -n "$BACKUP_NAME" ]; then
        say "Current Name: ${GREEN}${BACKUP_NAME}${NC}"
        read -p "Naya Name? Enter=same, ya naya likho: " newname
        [ -n "$newname" ] && save_backup_name "$newname"
    else
        say "${YELLOW}Backup Name (panel / node1 / node2):${NC}"
        read -p "Name: " newname
        [ -z "$newname" ] && newname="panel"
        save_backup_name "$newname"
    fi
    load_backup_name
    say "${GREEN}Backup Name Lock: ${BACKUP_NAME}${NC}"
    echo ""

    create_auto_worker

    local tmp
    tmp=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$WORKER" > "$tmp" || true
    echo "*/${INTERVAL_MIN} * * * * /bin/bash $WORKER >/dev/null 2>&1" >> "$tmp"
    crontab "$tmp"
    rm -f "$tmp"

    say "${GREEN}✓ Auto-Backup ON (har ${INTERVAL_MIN} min) — Name: ${BACKUP_NAME}${NC}"
    say "${YELLOW}Pehla backup abhi shuru...${NC}"
    echo ""

    run_backup
    read -p "Enter dabayein..." t
}

stop_auto_backup() {
    crontab -l 2>/dev/null | grep -v "$WORKER" | crontab -
    say "${GREEN}Auto-Backup OFF!${NC}"
    sleep 2
}

# ==================== AUTO-SETUP HELPERS ====================
install_panel_stack() {
    if command -v php >/dev/null 2>&1 && command -v nginx >/dev/null 2>&1 \
       && command -v mysql >/dev/null 2>&1 && command -v redis-server >/dev/null 2>&1 \
       && command -v supervisorctl >/dev/null 2>&1; then
        return 0
    fi
    say "${YELLOW}Panel Stack Install (PHP ${PHP_VER} + Nginx + MySQL + Redis)...${NC}"
    . /etc/os-release
    apt-get update -y >>"$LOG" 2>&1
    apt-get install -y software-properties-common curl gnupg ca-certificates lsb-release apt-transport-https >>"$LOG" 2>&1

    if [ "$ID" = "ubuntu" ]; then
        add-apt-repository -y ppa:ondrej/php >>"$LOG" 2>&1
    elif [ "$ID" = "debian" ]; then
        curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb >>"$LOG" 2>&1
        dpkg -i /tmp/debsuryorg-archive-keyring.deb >>"$LOG" 2>&1
        echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/php.list
    fi
    apt-get update -y >>"$LOG" 2>&1

    # NOTE: php-tokenizer / php-readline alag package nahi hote — pura apt install fail ho jata tha
    apt-get install -y nginx redis-server unzip git supervisor \
        php${PHP_VER} php${PHP_VER}-{cli,fpm,common,mysql,mbstring,xml,bcmath,sqlite3,curl,zip,gd,intl,gmp} >>"$LOG" 2>&1
    local rc=$?

    command -v mysql >/dev/null 2>&1 && command -v mysqld >/dev/null 2>&1 || {
        apt-get install -y mysql-server >>"$LOG" 2>&1 || apt-get install -y mariadb-server >>"$LOG" 2>&1
    }

    systemctl enable --now nginx redis-server "php${PHP_VER}-fpm" supervisor >/dev/null 2>&1 || true
    systemctl enable --now mysql >/dev/null 2>&1 || systemctl enable --now mariadb >/dev/null 2>&1 || true

    if [ $rc -ne 0 ] || ! command -v php >/dev/null 2>&1; then
        say "${RED}   ✗ Stack install me error aaya. Log dekhein: $LOG${NC}"
        return 1
    fi
    say "${GREEN}   ✓ Stack installed${NC}"
}

install_docker() {
    command -v docker >/dev/null 2>&1 && return 0
    say "${YELLOW}Docker install...${NC}"
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash >>"$LOG" 2>&1
    systemctl enable --now docker >/dev/null 2>&1
    command -v docker >/dev/null 2>&1
}

ensure_db_user() {
    local u="$1" p="$2" d="$3" h ep
    [ -z "$p" ] && return 0
    ep=${p//\\/\\\\}
    ep=${ep//\'/\\\'}
    mysql_root -e "CREATE DATABASE IF NOT EXISTS \`${d}\`;"
    for h in 127.0.0.1 localhost; do
        mysql_root -e "CREATE USER IF NOT EXISTS '${u}'@'${h}' IDENTIFIED BY '${ep}'; ALTER USER '${u}'@'${h}' IDENTIFIED BY '${ep}'; GRANT ALL PRIVILEGES ON \`${d}\`.* TO '${u}'@'${h}';"
    done
    mysql_root -e "FLUSH PRIVILEGES;"
}

restore_sql_dump() {
    local dump="$STAGING/pterodactyl_database_dump.sql"
    [ -s "$dump" ] || dump="/root/pterodactyl_database_dump.sql"
    if [ ! -s "$dump" ]; then
        say "${YELLOW}   ! SQL dump backup me nahi mila — sirf raw DB (Layer 2) use hoga.${NC}"
        return 0
    fi
    command -v mysql >/dev/null 2>&1 || { say "${YELLOW}   ! mysql client nahi hai — dump skip.${NC}"; return 0; }
    say "${YELLOW}Layer 1: SQL Dump import ho raha hai...${NC}"
    if mysql_root -e "SOURCE ${dump}"; then
        say "${GREEN}   ✓ SQL Database Restored!${NC}"
        [ "$dump" = "/root/pterodactyl_database_dump.sql" ] && rm -f "$dump"
    else
        say "${RED}   ✗ SQL import fail — log: $LOG${NC}"
        return 1
    fi
}

fresh_init_mysql() {
    local ts; ts=$(date +%s)
    systemctl stop mysql mariadb >/dev/null 2>&1
    mv /var/lib/mysql "/var/lib/mysql.broken.${ts}"
    mkdir -p /var/lib/mysql && chown mysql:mysql /var/lib/mysql
    if mysqld --version 2>/dev/null | grep -qi mariadb; then
        mysql_install_db --user=mysql --datadir=/var/lib/mysql >>"$LOG" 2>&1
    else
        mysqld --initialize-insecure --user=mysql >>"$LOG" 2>&1
    fi
    start_mysql
    wait_mysql
}

# ==================== AUTO SETUP PANEL + BLUEPRINT ====================
auto_setup_panel() {
    say "${CYAN}--- PANEL & BLUEPRINT AUTO-SETUP ---${NC}"
    install_panel_stack || return 1

    if [ ! -d /var/www/pterodactyl ]; then
        say "${RED}   Panel directory nahi mili${NC}"
        return 1
    fi

    start_mysql
    wait_mysql || say "${YELLOW}   ! MySQL respond nahi kar raha — log: $LOG${NC}"

    local DB_USER="pterodactyl" DB_PASS="" DB_NAME="panel" v
    v=$(env_get DB_USERNAME); [ -n "$v" ] && DB_USER="$v"
    v=$(env_get DB_PASSWORD); [ -n "$v" ] && DB_PASS="$v"
    v=$(env_get DB_DATABASE); [ -n "$v" ] && DB_NAME="$v"

    say "${YELLOW}MySQL Database & Permissions Setup...${NC}"
    ensure_db_user "$DB_USER" "$DB_PASS" "$DB_NAME"

    cd /var/www/pterodactyl || return 1
    chown -R www-data:www-data /var/www/pterodactyl 2>/dev/null
    chmod -R 755 storage bootstrap/cache 2>/dev/null

    say "${YELLOW}Blueprint & Addons Cache Sync...${NC}"
    local art=(runuser -u www-data -- php artisan) c
    "${art[@]}" migrate --force >>"$LOG" 2>&1 || say "${YELLOW}   ! migrate me warning (log dekhein)${NC}"
    for c in config:clear cache:clear view:clear route:clear; do
        "${art[@]}" $c >>"$LOG" 2>&1
    done
    if [ -f blueprint.sh ]; then
        chmod +x blueprint.sh
        bash blueprint.sh -rerun-install </dev/null >>"$LOG" 2>&1 || true
    fi
    chown -R www-data:www-data /var/www/pterodactyl 2>/dev/null

    # ---- Nginx: restore hui config (SSL wali) ko overwrite NAHI karte ----
    rm -f /etc/nginx/sites-enabled/default
    if grep -Rqs "/var/www/pterodactyl/public" /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>/dev/null; then
        say "${GREEN}   ✓ Restore hui Nginx config use ho rahi hai${NC}"
        # php-fpm socket version mismatch fix
        grep -Rl 'unix:/run/php/php' /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>/dev/null \
            | xargs -r sed -i --follow-symlinks -E "s#unix:/run/php/php[0-9.]+-fpm\.sock#unix:/run/php/php${PHP_VER}-fpm.sock#g"
    else
        local DOMAIN
        DOMAIN=$(env_get APP_URL | sed -E 's|https?://||; s|/.*||')
        [ -z "$DOMAIN" ] && DOMAIN="_"
        cat > /etc/nginx/sites-available/pterodactyl.conf <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name __DOMAIN__ _;
    root /var/www/pterodactyl/public;
    index index.php;
    client_max_body_size 100m;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php__PHP__-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
        sed -i "s/__DOMAIN__/${DOMAIN}/; s/__PHP__/${PHP_VER}/" /etc/nginx/sites-available/pterodactyl.conf
        ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
        say "${GREEN}   ✓ Fallback Nginx config bani: ${DOMAIN}${NC}"
    fi
    if nginx -t >>"$LOG" 2>&1; then
        systemctl restart nginx
    else
        say "${RED}   ✗ nginx -t fail! Check: nginx -t${NC}"
    fi

    # ---- Queue worker ----
    systemctl daemon-reload
    if systemctl list-unit-files 2>/dev/null | grep -q '^pteroq'; then
        systemctl enable --now pteroq >/dev/null 2>&1
        sleep 1
        if systemctl is-active --quiet pteroq; then
            say "${GREEN}   ✓ pteroq (queue worker) chalu${NC}"
        else
            say "${YELLOW}   ! pteroq start nahi hua${NC}"
        fi
    elif [ ! -f /etc/supervisor/conf.d/pterodactyl-worker.conf ]; then
        cat > /etc/supervisor/conf.d/pterodactyl-worker.conf << 'EOF'
[program:pterodactyl-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
autostart=true
autorestart=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/pterodactyl/storage/logs/queue-worker.log
EOF
        supervisorctl reread >/dev/null 2>&1
        supervisorctl update >/dev/null 2>&1
        say "${GREEN}   ✓ Supervisor Queue Worker chalu${NC}"
    else
        systemctl restart supervisor >/dev/null 2>&1
    fi

    # ---- Panel scheduler cron ----
    if ! crontab -l 2>/dev/null | grep -q 'artisan schedule:run'; then
        ( crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" ) | crontab -
    fi

    systemctl restart "php${PHP_VER}-fpm" redis-server >/dev/null 2>&1
    say "${GREEN}✓ PANEL & BLUEPRINT AUTO-SETUP DONE!${NC}"
}

# ==================== AUTO SETUP WINGS ====================
auto_setup_wings() {
    say "${CYAN}--- WINGS AUTO-SETUP ---${NC}"
    install_docker || { say "${RED}   ✗ Docker install fail (log: $LOG)${NC}"; return 1; }

    mkdir -p /etc/pterodactyl /var/lib/pterodactyl
    if [ ! -x /usr/local/bin/wings ]; then
        say "${YELLOW}Wings binary install...${NC}"
        local arch="arm64"
        [ "$(uname -m)" = "x86_64" ] && arch="amd64"
        curl -fsSL -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${arch}" >>"$LOG" 2>&1
        chmod u+x /usr/local/bin/wings
    fi

    if [ ! -f /etc/systemd/system/wings.service ]; then
        cat > /etc/systemd/system/wings.service <<'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    fi
    systemctl daemon-reload
    chmod 600 /etc/pterodactyl/config.yml 2>/dev/null || true
    systemctl enable wings >/dev/null 2>&1
    # docker restart nahi karte (chalu containers ruk jate hain)
    systemctl is-active --quiet docker || systemctl start docker
    sleep 2
    systemctl restart wings >/dev/null 2>&1
    sleep 2

    if systemctl is-active --quiet wings; then
        say "${GREEN}✓ WINGS RUNNING!${NC}"
    else
        say "${YELLOW}   ! Wings nahi chali. /etc/pterodactyl/config.yml hai? Check: journalctl -u wings -n 30${NC}"
    fi
}

# ==================== AUTO SETUP CLOUDFLARE ====================
auto_setup_cloudflared() {
    say "${CYAN}--- CLOUDFLARE TUNNEL AUTO-SETUP ---${NC}"

    if [ -f "$STAGING/cloudflared_token_backup" ]; then
        mkdir -p /etc/cloudflared
        cp "$STAGING/cloudflared_token_backup" /etc/cloudflared/token
        chmod 600 /etc/cloudflared/token
    fi

    if [ ! -f /etc/cloudflared/token ] && [ ! -f /etc/systemd/system/cloudflared.service ] \
       && [ ! -d /etc/cloudflared ] && [ ! -d /root/.cloudflared ]; then
        say "${YELLOW}   ! Cloudflared ka data/token nahi mila — skip.${NC}"
        return 0
    fi

    if ! command -v cloudflared >/dev/null 2>&1; then
        say "${YELLOW}Cloudflared install...${NC}"
        mkdir -p --mode=0755 /usr/share/keyrings
        curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg -o /usr/share/keyrings/cloudflare-public-v2.gpg >>"$LOG" 2>&1
        echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' > /etc/apt/sources.list.d/cloudflared.list
        apt-get update -y >>"$LOG" 2>&1
        apt-get install -y cloudflared >>"$LOG" 2>&1
    fi

    local TOKEN=""
    [ -f /etc/cloudflared/token ] && TOKEN=$(cat /etc/cloudflared/token)
    if [ -n "$TOKEN" ]; then
        cloudflared service uninstall >/dev/null 2>&1 || true
        cloudflared service install "$TOKEN" >>"$LOG" 2>&1 || true
    fi
    systemctl daemon-reload
    systemctl enable --now cloudflared >/dev/null 2>&1
    systemctl restart cloudflared >/dev/null 2>&1

    if systemctl is-active --quiet cloudflared; then
        say "${GREEN}   ✓ Cloudflared Tunnel Running!${NC}"
    else
        say "${YELLOW}   ! Cloudflared chalu nahi hua (journalctl -u cloudflared -n 30)${NC}"
    fi
}

auto_setup_tailscale() {
    if [ -d /var/lib/tailscale ]; then
        say "${CYAN}--- TAILSCALE AUTO-SETUP ---${NC}"
        command -v tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh >>"$LOG" 2>&1
        systemctl enable --now tailscaled >/dev/null 2>&1
        say "${GREEN}   ✓ Tailscale Ready${NC}"
    fi
}


# ==================== START-ALL (no-systemd containers ke liye) ====================
write_start_script() {
    cat > /root/start_all.sh <<'EOF'
#!/bin/bash
# Container restart ke baad chalayein:  bash /root/start_all.sh
PHP_VER="__PHP__"
mkdir -p /var/run/mysqld; chown mysql:mysql /var/run/mysqld 2>/dev/null
for s in cron mysql mariadb redis-server php${PHP_VER}-fpm nginx supervisor docker; do
    service "$s" start >/dev/null 2>&1 && echo "started: $s"
done
pgrep -f 'artisan queue:work' >/dev/null || { setsid nohup runuser -u www-data -- php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3 >>/var/log/pteroq.log 2>&1 </dev/null & }
T=""
[ -s /etc/cloudflared/token ] && T=$(tr -d '\r\n' < /etc/cloudflared/token)
if [ -z "$T" ] && [ -f /etc/systemd/system/cloudflared.service ]; then
    T=$(grep -oE 'token [A-Za-z0-9=_.-]+' /etc/systemd/system/cloudflared.service | head -1 | awk '{print $NF}')
fi
if [ -n "$T" ] && ! pgrep -f 'cloudflared.*tunnel' >/dev/null; then
    setsid nohup cloudflared tunnel --no-autoupdate run --token "$T" >>/var/log/cloudflared.log 2>&1 </dev/null &
    echo "started: cloudflared"
fi
if [ -x /usr/local/bin/wings ] && ! pgrep -x wings >/dev/null && docker info >/dev/null 2>&1; then
    ( cd /etc/pterodactyl && setsid nohup /usr/local/bin/wings >>/var/log/wings.log 2>&1 </dev/null & )
    echo "started: wings"
fi
EOF
    sed -i "s/__PHP__/${PHP_VER}/" /root/start_all.sh
    chmod 700 /root/start_all.sh
}

# ==================== 2) RESTORE + AUTO SETUP ====================
restore_backup() {
    clear
    if ! check_blomp_login; then sleep 2; return; fi

    say "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    say "${CYAN}║  RESTORE + AUTO SETUP (Panel/Wings Online)   ║${NC}"
    say "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    say "${YELLOW}Step 1: Node / Folder choose karein${NC}"
    echo ""

    local folders=() inner_files=() i fname choice fchoice
    mapfile -t folders < <(rclone lsf "${REMOTE_NAME}:${BLOMP_USER}/${BACKUP_FOLDER}/" --dirs-only "${RCLONE_FLAGS[@]}" 2>/dev/null)

    if [ ${#folders[@]} -eq 0 ]; then
        say "${RED}Blomp par koi backup folder nahi mila!${NC}"
        sleep 2; return
    fi

    say "${GREEN}Available Folders:${NC}"
    for i in "${!folders[@]}"; do
        fname="${folders[$i]%/}"
        say "  ${YELLOW}$((i+1)))${NC} ${CYAN}[FOLDER]${NC} ${fname}/"
    done
    echo ""
    read -p "Number choose [1-${#folders[@]}] (0=back): " choice
    [ "$choice" = "0" ] && return
    [[ "$choice" =~ ^[0-9]+$ ]] || return
    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#folders[@]}" ]; then return; fi

    local selected_folder="${folders[$((choice-1))]%/}"

    echo ""
    say "${YELLOW}Step 2: ${selected_folder}/ ke andar backup choose karein${NC}"
    mapfile -t inner_files < <(
        rclone lsf "${REMOTE_NAME}:${BLOMP_USER}/${BACKUP_FOLDER}/${selected_folder}/" \
            --files-only --include "*.tar.gz" "${RCLONE_FLAGS[@]}" 2>/dev/null | sort -r
    )
    if [ ${#inner_files[@]} -eq 0 ]; then
        say "${RED}Is folder mein koi backup nahi hai!${NC}"
        sleep 2; return
    fi

    say "${GREEN}Available Backups:${NC}"
    for i in "${!inner_files[@]}"; do
        say "  ${YELLOW}$((i+1)))${NC} ${inner_files[$i]}"
    done
    echo ""
    read -p "Number choose [1-${#inner_files[@]}] (0=back): " fchoice
    [ "$fchoice" = "0" ] && return
    [[ "$fchoice" =~ ^[0-9]+$ ]] || return
    if [ "$fchoice" -lt 1 ] || [ "$fchoice" -gt "${#inner_files[@]}" ]; then return; fi

    local selected_file="${inner_files[$((fchoice-1))]}"
    local SRC="${REMOTE_NAME}:${BLOMP_USER}/${BACKUP_FOLDER}/${selected_folder}/${selected_file}"
    local LOCAL="${WORK_DIR}/${selected_file}"

    echo ""
    say "${RED}⚠ WARNING: Restore se is server ki /root, /etc, /var/www, /var/lib/mysql, /home etc. files OVERWRITE hongi.${NC}"
    read -p "Aage badhne ke liye YES likhein: " confirm
    [ "$confirm" = "YES" ] || { say "Cancelled."; sleep 1; return; }

    echo ""
    say "${CYAN}==================================================${NC}"
    say "${YELLOW}[1/6] Downloading: ${selected_file}${NC}"
    say "${CYAN}==================================================${NC}"
    mkdir -p "$WORK_DIR"
    rclone copyto "$SRC" "$LOCAL" "${RCLONE_FLAGS[@]}" --progress

    if [ ! -s "$LOCAL" ]; then
        say "${RED}✗ Download Fail!${NC}"
        read -p "Enter dabayein..." t
        return
    fi
    local COMP="gzip"; command -v pigz >/dev/null 2>&1 && COMP="pigz"
    if ! "$COMP" -t "$LOCAL" 2>>"$LOG"; then
        say "${RED}✗ Downloaded archive corrupt hai — restore cancel.${NC}"
        rm -f "$LOCAL"
        read -p "Enter dabayein..." t
        return
    fi

    # Manifest se pata chalta hai panel/wings is backup me hain ya nahi
    local MANIFEST HAS_PANEL=1 HAS_WINGS=1
    MANIFEST=$(tar -xzf "$LOCAL" -O --wildcards --occurrence=1 '*backup_staging/manifest.txt' 2>/dev/null)
    if [ -n "$MANIFEST" ]; then
        echo "$MANIFEST" | grep -qx 'path=/var/www/pterodactyl' || HAS_PANEL=0
        echo "$MANIFEST" | grep -Eqx 'path=/(etc|var/lib)/pterodactyl' || HAS_WINGS=0
    fi

    echo ""
    say "${CYAN}[2/6] Pehle software install (extract se PEHLE, taaki MySQL data na toote)...${NC}"
    [ $HAS_PANEL -eq 1 ] && { install_panel_stack || say "${YELLOW}   ! Stack install me dikkat (log: $LOG)${NC}"; }

    systemctl stop wings pteroq nginx "php${PHP_VER}-fpm" mysql mariadb >/dev/null 2>&1 || true

    echo ""
    say "${CYAN}[3/6] Extracting Files...${NC}"
    tar -xzf "$LOCAL" -C / 2>>"$LOG"
    local TRC=$?
    rm -f "$LOCAL"
    if [ $TRC -gt 1 ]; then
        say "${YELLOW}   ! Extract me errors aaye (rc=$TRC) — log dekhein: $LOG${NC}"
    else
        say "${GREEN}   ✓ Files restored${NC}"
    fi
    systemctl daemon-reload

    echo ""
    say "${CYAN}[4/6] Database start + SQL import...${NC}"
    if [ -d /var/lib/mysql ]; then
        chown -R mysql:mysql /var/lib/mysql 2>/dev/null
        start_mysql
        if ! wait_mysql; then
            say "${YELLOW}   ! Raw datadir se MySQL start nahi hua.${NC}"
            tail -n 8 /var/log/mysql/error.log 2>/dev/null
            read -p "   Fresh MySQL init karein? (purana data /var/lib/mysql.broken.* me rakha jayega) [y/N]: " ans
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                fresh_init_mysql || say "${RED}   ✗ MySQL phir bhi start nahi hua. Log: $LOG${NC}"
            else
                say "${YELLOW}   Skip — data /var/lib/mysql me untouched hai.${NC}"
            fi
        else
            say "${GREEN}   ✓ Layer 2: Raw MySQL start ho gaya${NC}"
        fi
    fi
    restore_sql_dump

    echo ""
    say "${CYAN}[5/6] Panel & Blueprint + Wings Auto-Setup...${NC}"
    if [ -d /var/www/pterodactyl ]; then auto_setup_panel; else say "${YELLOW}   Panel is backup me nahi — skip${NC}"; fi
    if [ -d /etc/pterodactyl ] || [ -d /var/lib/pterodactyl ]; then auto_setup_wings; else say "${YELLOW}   Wings is backup me nahi — skip${NC}"; fi

    echo ""
    say "${CYAN}[6/6] Cloudflared + Tailscale...${NC}"
    auto_setup_cloudflared
    auto_setup_tailscale
    rm -rf "$STAGING"      # plaintext SQL/token disk par na chhode
    if [ "$HAS_SYSTEMD" -eq 0 ]; then
        write_start_script
        say "${YELLOW}ℹ systemd nahi hai (container). Restart ke baad ye chalayein: ${GREEN}bash /root/start_all.sh${NC}"
    fi
    systemctl restart cron >/dev/null 2>&1 || true

    echo ""
    say "${GREEN}════════════════════════════════════════════════════${NC}"
    say "${GREEN} ✓ RESTORE + AUTO-SETUP COMPLETE!                   ${NC}"
    say "${GREEN}════════════════════════════════════════════════════${NC}"

    echo ""
    say "${CYAN}Live Services Status:${NC}"
    local svc
    for svc in nginx mysql mariadb redis-server "php${PHP_VER}-fpm" docker wings pteroq cloudflared tailscaled supervisor; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            say "  ${GREEN}✓ RUNNING${NC}  $svc"
        elif systemctl list-unit-files 2>/dev/null | grep -q "^$svc"; then
            say "  ${RED}✗ STOPPED${NC}  $svc"
        fi
    done

    if [ -f /var/www/pterodactyl/.env ]; then
        echo ""
        say "${CYAN}Panel URL: ${YELLOW}$(env_get APP_URL)${NC}"
    fi
    echo ""
    read -p "Enter dabayein..." t
}

# ==================== 4) BACKUP LIST ====================
show_backups() {
    clear
    if ! check_blomp_login; then sleep 2; return; fi
    say "${CYAN}==================================================${NC}"
    say "${CYAN}   BLOMP CLOUD BACKUP TREE${NC}"
    say "${CYAN}==================================================${NC}"
    echo ""

    local folders=() f fname
    mapfile -t folders < <(rclone lsf "${REMOTE_NAME}:${BLOMP_USER}/${BACKUP_FOLDER}/" --dirs-only "${RCLONE_FLAGS[@]}" 2>/dev/null)

    if [ ${#folders[@]} -eq 0 ]; then
        say "${YELLOW}Koi backup folder nahi mila.${NC}"
    else
        for f in "${folders[@]}"; do
            fname="${f%/}"
            say "${GREEN}📁 ${fname}/${NC}"
            rclone lsl "${REMOTE_NAME}:${BLOMP_USER}/${BACKUP_FOLDER}/${fname}/" --include "*.tar.gz" "${RCLONE_FLAGS[@]}" 2>/dev/null | while read -r line; do
                say "     └── $line"
            done
            echo ""
        done
    fi
    read -p "Enter dabayein..." t
}

# ==================== 7) MANUAL FULL SETUP ====================
manual_full_setup() {
    clear
    say "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    say "${CYAN}║   MANUAL FULL SETUP (Fresh Install)          ║${NC}"
    say "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    say "${YELLOW}1) Panel & Blueprint Auto-Setup${NC}"
    say "${YELLOW}2) Wings + Docker Auto-Setup${NC}"
    say "${YELLOW}3) Cloudflared Auto-Setup${NC}"
    say "${YELLOW}4) Tailscale Auto-Setup${NC}"
    say "${YELLOW}5) ALL (Sab kuch)${NC}"
    say "${YELLOW}0) Back${NC}"
    echo ""
    read -p "Option: " opt

    case "$opt" in
        1) auto_setup_panel ;;
        2) auto_setup_wings ;;
        3) auto_setup_cloudflared ;;
        4) auto_setup_tailscale ;;
        5) auto_setup_panel; auto_setup_wings; auto_setup_cloudflared; auto_setup_tailscale ;;
        0) return ;;
    esac
    read -p "Enter dabayein..." t
}

# ==================== MAIN MENU ====================
install_all_dependencies
load_blomp_config
load_backup_name

while true; do
    clear
    load_backup_name
    say "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    say "${GREEN}║   SMART BACKUP MANAGER v16 (Double-DB Master)  ║${NC}"
    say "${GREEN}╠════════════════════════════════════════════════╣${NC}"
    if [ -n "$BACKUP_NAME" ]; then
        say "${GREEN}║${NC}  Name: ${YELLOW}${BACKUP_NAME}${NC}   Folder: ${YELLOW}${BACKUP_FOLDER}/${BACKUP_NAME}/${NC}"
    fi
    say "${GREEN}║ ${YELLOW}1)${NC} Auto-Backup ON (${INTERVAL_MIN} min + Everything!)"
    say "${GREEN}║ ${YELLOW}2)${NC} Restore & Auto-Setup (Live Online)"
    say "${GREEN}║ ${YELLOW}3)${NC} Blomp Login"
    say "${GREEN}║ ${YELLOW}4)${NC} Backup List (Tree View)"
    say "${GREEN}║ ${YELLOW}5)${NC} Important Data, Services & Log Check"
    say "${GREEN}║ ${YELLOW}6)${NC} Auto-Backup OFF"
    say "${GREEN}║ ${YELLOW}7)${NC} Manual Full Setup (Panel/Wings Fresh)"
    say "${GREEN}║ ${YELLOW}0)${NC} Exit"
    say "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    read -p "Option: " opt
    case "$opt" in
        1) start_auto_backup ;;
        2) restore_backup ;;
        3) setup_blomp ;;
        4) show_backups ;;
        5) clear; show_important_data; read -p "Enter dabayein..." t ;;
        6) stop_auto_backup ;;
        7) manual_full_setup ;;
        0) exit 0 ;;
        *) sleep 1 ;;
    esac
done
