# Zircon Vibrator Bridge — Magisk prototype

Experimental module for the Redmi Note 13 Pro+ 5G (`zircon`) HyperOS port.

## Important limitations

- This is a diagnostic prototype, not a confirmed fix.
- It launches the existing ARM64 `vibrator-bridge` binary from the module directory.
- It does not flash or repack `vendor.img`, and does not replace Xiaomi's `vibratorfeature` HAL.
- A Magisk-launched process may still be rejected by SELinux or Binder service-manager policy. The included `sepolicy.rule` is deliberately limited to the bridge's expected service/Binder access, but must be validated on-device.
- This module does not modify the VINTF manifest. Runtime registration may therefore succeed while framework integration still fails, depending on the port's VINTF setup.
- Do not flash vendor images as part of testing this module.

## Install

1. Boot Android normally with Magisk installed.
2. Install the generated `zircon-vibrator-bridge-magisk.zip` in Magisk > Modules > Install from storage.
3. Reboot.
4. Inspect `/data/adb/vibrator-bridge/service.log`.
5. Check whether both instances exist:
   ```sh
   su -c 'service list | grep -E "IVibrator/default|IVibrator/vibratorfeature"'
   su -c 'pidof vibrator-bridge'
   su -c 'logcat -b all -d | grep -E "vibrator-bridge|avc: denied" | tail -n 100'
   ```

## Recovery

If Android remains bootable, disable the module in Magisk and reboot. From recovery with data decrypted, remove:

```sh
/data/adb/modules/zircon_vibrator_bridge
```

The module should not require a vendor image restore because it does not write to vendor.

## Build

The repository workflow packages this directory and copies the tracked binary from `vendor/bin/hw/vibrator-bridge` into the installable module ZIP.
