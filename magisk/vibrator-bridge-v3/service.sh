#!/system/bin/sh
# Zircon vibrator bridge v3.
# Unlike v2, label the one bridge executable with the ROM's existing
# hal_vibrator_default_exec type before exec, so the transition is scoped to
# this executable rather than every system_file process launched by Magisk.

MODDIR="${0%/*}"
LOGDIR="/data/adb/vibrator-bridge"
LOG="$LOGDIR/service.log"
BIN="$MODDIR/vibrator-bridge"
EXPECTED_DOMAIN="u:r:hal_vibrator_default:s0"
EXPECTED_EXEC="u:object_r:hal_vibrator_default_exec:s0"
XIAOMI_SERVICE="android.hardware.vibrator.IVibrator/vibratorfeature"
FRAMEWORK_SERVICE="android.hardware.vibrator.IVibrator/default"

mkdir -p "$LOGDIR"
chmod 0755 "$LOGDIR" 2>/dev/null
touch "$LOG"
chmod 0644 "$LOG" 2>/dev/null

log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG"
}

{
    echo
    echo "===== vibrator-bridge v3 startup: $(date) ====="
    echo "module=$MODDIR"
    echo "script_domain=$(cat /proc/self/attr/current 2>/dev/null)"
    echo "selinux_enforce=$(cat /sys/fs/selinux/enforce 2>/dev/null)"
    echo "binary=$BIN"
    echo "binary_context_before=$(ls -Z "$BIN" 2>&1)"
} >> "$LOG" 2>&1

# Magisk extraction may leave the binary at mode 0644 even when the ZIP was
# assembled incorrectly. Repair its executable bit before testing it.
if [ -f "$BIN" ]; then
    chmod 0755 "$BIN" >> "$LOG" 2>&1
fi
if [ ! -f "$BIN" ] || [ ! -x "$BIN" ]; then
    log "ERROR: bridge binary is missing or still not executable after chmod; refusing launch."
    ls -lZ "$BIN" >> "$LOG" 2>&1
    exit 1
fi

if [ "$(cat /sys/fs/selinux/enforce 2>/dev/null)" != "1" ]; then
    log "ERROR: expected enforcing SELinux; refusing to treat a permissive run as valid."
fi

# The v2 rule matched module_file, but the live binary was system_file.
# Set the dedicated exec type and verify it before attempting to launch.
if ! command -v chcon >/dev/null 2>&1; then
    log "ERROR: chcon is unavailable; cannot label the bridge safely."
    exit 1
fi
if ! chcon "$EXPECTED_EXEC" "$BIN" >> "$LOG" 2>&1; then
    log "ERROR: failed to label bridge as $EXPECTED_EXEC; refusing launch."
    exit 1
fi
ACTUAL_EXEC="$(ls -Z "$BIN" 2>/dev/null)"
log "binary_context_after=$ACTUAL_EXEC"
case "$ACTUAL_EXEC" in
    *"$EXPECTED_EXEC"*) ;;
    *)
        log "ERROR: executable label verification failed; refusing launch."
        exit 1
        ;;
esac

# Wait for the existing Xiaomi HAL; never stop or restart that vendor service.
i=0
while [ "$i" -lt 90 ]; do
    if service check "$XIAOMI_SERVICE" >/dev/null 2>&1; then
        break
    fi
    sleep 1
    i=$((i + 1))
done
log "xiaomi_service_wait_seconds=$i"
service check "$XIAOMI_SERVICE" >> "$LOG" 2>&1
if ! service check "$XIAOMI_SERVICE" >/dev/null 2>&1; then
    log "ERROR: Xiaomi vibrator HAL unavailable; refusing launch."
    exit 1
fi

# Stop only an older instance of this bridge, and wait for it to exit.
for pid in $(pidof vibrator-bridge 2>/dev/null); do
    current="$(cat "/proc/$pid/attr/current" 2>/dev/null)"
    log "existing_pid=$pid existing_domain=$current"
    if [ "$current" = "$EXPECTED_DOMAIN" ]; then
        log "A bridge instance already runs in the expected domain; not launching a duplicate."
        exit 0
    fi
    log "Stopping stale bridge process $pid (not the Xiaomi HAL)."
    kill "$pid" 2>/dev/null
done

i=0
while pidof vibrator-bridge >/dev/null 2>&1 && [ "$i" -lt 10 ]; do
    sleep 1
    i=$((i + 1))
done
if pidof vibrator-bridge >/dev/null 2>&1; then
    log "ERROR: old bridge did not exit; refusing duplicate launch."
    exit 1
fi

log "Launching bridge with dedicated exec label."
"$BIN" >> "$LOG" 2>&1 &
pid=$!
log "launch_pid=$pid"
sleep 2

if kill -0 "$pid" 2>/dev/null; then
    domain="$(cat "/proc/$pid/attr/current" 2>/dev/null)"
    log "process_alive=yes"
    log "process_domain=$domain"
    if [ "$domain" != "$EXPECTED_DOMAIN" ]; then
        log "ERROR: domain transition failed; stopping the wrongly labelled bridge."
        kill "$pid" 2>/dev/null
        exit 1
    fi
else
    log "ERROR: bridge exited during startup."
    exit 1
fi

log "--- vibrator service registration check ---"
service list 2>&1 | grep -E 'IVibrator/(default|vibratorfeature)' >> "$LOG"
service check "$FRAMEWORK_SERVICE" >> "$LOG" 2>&1
if service check "$FRAMEWORK_SERVICE" >/dev/null 2>&1; then
    log "framework_service_registered=yes"
else
    log "framework_service_registered=no"
fi

log "--- recent SELinux denials / bridge diagnostics ---"
logcat -b all -d 2>/dev/null | grep -iE 'avc: denied|vibrator-bridge|IVibrator/default|vibratorfeature|not allowed to add' | tail -n 100 >> "$LOG"

log "Startup checks complete. Service registration and physical haptics still require on-device verification."
exit 0
