#!/system/bin/sh
# Magisk late_start service for the zircon vibrator bridge.
# The v2 sepolicy.rule attempts to transition the bridge from magisk into
# hal_vibrator_default; this script records the actual runtime domain so that
# the transition can be verified instead of assumed.

MODDIR="${0%/*}"
LOGDIR="/data/adb/vibrator-bridge"
LOG="$LOGDIR/service.log"
BIN="$MODDIR/vibrator-bridge"
EXPECTED_DOMAIN="u:r:hal_vibrator_default:s0"

mkdir -p "$LOGDIR"
chmod 0755 "$BIN" 2>/dev/null

{
    echo
    echo "===== vibrator-bridge v2 startup: $(date) ====="
    echo "module=$MODDIR"
    echo "script_domain=$(cat /proc/self/attr/current 2>/dev/null)"
    echo "selinux_enforce=$(cat /sys/fs/selinux/enforce 2>/dev/null)"
    echo "binary_context=$(ls -Z "$BIN" 2>&1)"
    echo "binary_type=$(file "$BIN" 2>&1)"
} >> "$LOG" 2>&1

# Wait for the Xiaomi implementation before launching the client bridge.
i=0
while [ "$i" -lt 90 ]; do
    if service check android.hardware.vibrator.IVibrator/vibratorfeature >/dev/null 2>&1; then
        break
    fi
    sleep 1
    i=$((i + 1))
done
echo "xiaomi_service_wait_seconds=$i" >> "$LOG"
service check android.hardware.vibrator.IVibrator/vibratorfeature >> "$LOG" 2>&1

# If the vendor init service already started the bridge in the wrong domain,
# stop that instance so the new process can be launched with the v2 transition.
for pid in $(pidof vibrator-bridge 2>/dev/null); do
    current="$(cat "/proc/$pid/attr/current" 2>/dev/null)"
    echo "existing_pid=$pid existing_domain=$current" >> "$LOG"
    if [ "$current" != "$EXPECTED_DOMAIN" ]; then
        echo "Stopping bridge with unexpected domain." >> "$LOG"
        kill "$pid" 2>/dev/null
    else
        echo "Bridge already running in expected domain; leaving it alone." >> "$LOG"
        exit 0
    fi
done
sleep 2

if pidof vibrator-bridge >/dev/null 2>&1; then
    echo "ERROR: previous bridge process did not exit; refusing duplicate launch." >> "$LOG"
    exit 1
fi

echo "Launching bridge from $BIN" >> "$LOG"
"$BIN" >> "$LOG" 2>&1 &
pid=$!
echo "launch_pid=$pid" >> "$LOG"
sleep 2

if kill -0 "$pid" 2>/dev/null; then
    echo "process_alive=yes" >> "$LOG"
    echo "process_domain=$(cat "/proc/$pid/attr/current" 2>/dev/null)" >> "$LOG"
else
    echo "process_alive=no (bridge exited quickly)" >> "$LOG"
fi

echo "--- registered vibrator services ---" >> "$LOG"
service list 2>&1 | grep -E 'IVibrator/(default|vibratorfeature)' >> "$LOG"
echo "--- recent SELinux denials ---" >> "$LOG"
logcat -b all -d 2>/dev/null | grep -E 'avc: denied|vibrator-bridge|IVibrator/default' | tail -n 100 >> "$LOG"

exit 0
