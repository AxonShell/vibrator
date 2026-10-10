#!/system/bin/sh
# Magisk late_start service: launch the bridge without modifying vendor.
MODDIR="${0%/*}"
LOGDIR="/data/adb/vibrator-bridge"
LOG="$LOGDIR/service.log"
BIN="$MODDIR/vibrator-bridge"

mkdir -p "$LOGDIR"
chmod 0755 "$BIN" 2>/dev/null
{
    echo
    echo "===== vibrator-bridge startup: $(date) ====="
    echo "module=$MODDIR"
    echo "selinux=$(cat /sys/fs/selinux/enforce 2>/dev/null)"
} >> "$LOG"

# Avoid duplicate processes after a service-script rerun.
if pidof vibrator-bridge >/dev/null 2>&1; then
    echo "Bridge already running; leaving existing process untouched." >> "$LOG"
    exit 0
fi

# Wait briefly for Xiaomi's vendor HAL to register.
i=0
while [ "$i" -lt 60 ]; do
    if service check android.hardware.vibrator.IVibrator/vibratorfeature >/dev/null 2>&1; then
        break
    fi
    sleep 1
    i=$((i + 1))
done

echo "Launching bridge; Xiaomi HAL wait seconds=$i" >> "$LOG"
# Keep logs outside the module directory so updates do not erase them.
(
    exec "$BIN"
) >> "$LOG" 2>&1 &
echo "launch_pid=$!" >> "$LOG"
exit 0
