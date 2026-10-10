# Zircon Vibrator Bridge Magisk v3

Experimental bridge for the Redmi Note 13 Pro+ 5G (`zircon`) HyperOS port.

## Why v3 exists

The v2 phone diagnostics showed that the bridge executable was labelled `u:object_r:system_file:s0`, while its policy transition matched `module_file`. The bridge therefore remained in `u:r:magisk:s0` and `android.hardware.vibrator.IVibrator/default` was not registered.

The ROM already exposes the existing `hal_vibrator_default_exec` and `hal_vibrator_default` policy types. V3:

- labels only the module's bridge executable as `hal_vibrator_default_exec` before launch;
- uses a transition keyed to that dedicated executable type, not all `system_file` executions;
- verifies the file label and actual process domain, and fails closed if either check fails;
- never stops or restarts Xiaomi's `vibratorfeature` HAL;
- records whether the framework-facing AIDL service appears;
- keeps SELinux enforcing and does not modify or flash `vendor.img`.

The policy grants Magisk relabel permission from `system_file` toward the one existing vibrator executable type. Review the policy and the target ROM's live rules before using it; this is experimental and is not a guarantee that every ROM will allow the transition.

## Install and recover

1. Keep the original vendor recovery image available.
2. In Magisk, update/replace the existing module with the v3 ZIP and reboot.
3. If the phone does not boot normally, use the device's established recovery path. Do not flash a modified vendor image as part of this test.
4. Check the log before judging the result.

Log:
```sh
su -c 'cat /data/adb/vibrator-bridge/service.log'
su -c 'service list | grep -E "IVibrator/default|IVibrator/vibratorfeature"'
su -c 'cat /proc/$(pidof vibrator-bridge)/attr/current'
```

Expected diagnostic indicators are `binary_context_after=u:object_r:hal_vibrator_default_exec:s0`, `process_domain=u:r:hal_vibrator_default:s0`, and `framework_service_registered=yes`.

A successful ZIP build or a running process does **not** prove that vibration works. Test haptics manually after confirming the standard service is registered. If service registration fails, share the full log and do not disable SELinux.

## Known limitation

The bridge implementation is a prebuilt binary; the repository does not contain its source. GitHub Actions can validate and package it, but cannot verify Binder compatibility or physical vibration on the phone. The ROM's VINTF declaration was absent in the device-side search and is not synthesized by this Magisk-only module.
