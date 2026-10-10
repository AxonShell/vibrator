# Zircon Vibrator Bridge Magisk v2

Experimental runtime fix for the Redmi Note 13 Pro+ 5G (`zircon`) HyperOS port.

## What changed from v1

- Attempts a targeted SELinux process transition from the Magisk domain into `u:r:hal_vibrator_default:s0` when the bridge executable is launched.
- Logs the binary's file context and the bridge's actual runtime SELinux domain.
- Checks whether the Xiaomi `android.hardware.vibrator.IVibrator/vibratorfeature` service is present.
- Logs registered vibrator services and relevant SELinux denials.
- Does not modify or flash `vendor.img`, does not set SELinux permissive, and does not claim success just because the ZIP builds.

## Install safely

1. In Magisk, disable the previous **Zircon Vibrator Bridge** module if it is still installed.
2. Install `zircon-vibrator-bridge-magisk-v2.zip` from Magisk > Modules > Install from storage.
3. Reboot.
4. If Android boots, test vibration and then retrieve the log below.

The module keeps the same module ID (`zircon_vibrator_bridge`) so installing it as an update replaces the previous version. Reboot after updating so no old bridge process remains.

## Diagnostics

Log file:

```
/data/adb/vibrator-bridge/service.log
```

Use a root-authorized shell (approve the Magisk superuser prompt first):

```sh
su -c 'cat /data/adb/vibrator-bridge/service.log'
su -c 'service list | grep -E "IVibrator/default|IVibrator/vibratorfeature"'
su -c 'pidof vibrator-bridge'
su -c 'logcat -b all -d | grep -E "avc: denied|vibrator-bridge|IVibrator/default" | tail -n 100'
```

If the log says the process domain is not `u:r:hal_vibrator_default:s0`, the transition did not apply and this module is not a confirmed fix. Do not flash a vendor image based on this result alone.

## Known limitation

The bridge source is not available in this module's build step; the existing tracked binary is packaged unchanged. The workflow validates that it is an AArch64 ELF and attaches an ELF/string report, but it cannot test actual hardware haptics in GitHub Actions.
