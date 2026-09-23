# Android-side Termux recovery

**Rollout paused:** complete the [backup and recovery baseline](backup-and-restore.md) before installing or testing the watchdog. It is prepared, not deployed.

## Evidence from September 23, 2026

Android 12 / API 31, LG LM-G850, unrooted. Termux's recorded exit at
02:21:21 was SIGNALED / signal 9, subreason TRIM EMPTY, importance 125.
This does not establish the trigger. Later `PhantomProcessRecord ... died`
lines are exit notifications, not evidence that Android killed those processes.
The effective max_phantom_processes was already 2147483647, and Termux,
Termux:Boot, and Termux:API were already on the Doze whitelist. Do not
increase cached/empty process limits on the assumption they are phantom limits.

SSH is already supervised by Termux runit. The existing Termux:Boot script
acquires a wake lock and starts service-daemon. Neither is an independent
guarantee of recovery if Android terminates Termux and its children.

## Independent watchdog (prepared; device validation required)

`scripts/android-termux-watchdog.sh` runs as Android shell UID 2000, launched
through an authorized ADB connection. It checks for Termux and sshd processes
every 30 seconds. After three failures it saves Termux's exit history and
opens Termux's activity, then checks again. Attempts are limited to roughly
one per five minutes. It never force-stops or kills an application.

This checks process presence, not SSH responsiveness. Opening the activity
may not repair a failed SSH daemon if Termux is still alive. Existing runit
supervision handles individual daemon exits. Recovery remains best effort.

From a computer with the script available locally:

```powershell
adb push scripts/android-termux-watchdog.sh /data/local/tmp/android-termux-watchdog.sh
adb shell sh /data/local/tmp/android-termux-watchdog.sh check
# Harmless launch test: opens Termux without killing an existing session.
adb shell sh /data/local/tmp/android-termux-watchdog.sh recover
adb shell 'nohup setsid sh /data/local/tmp/android-termux-watchdog.sh watch </dev/null >/data/local/tmp/sanders-watchdog-launch.log 2>&1 &'
```

Check that heartbeat advances across two checks at least 30 seconds apart:

```powershell
adb shell sh /data/local/tmp/android-termux-watchdog.sh check
adb shell cat /data/local/tmp/sanders-watchdog/watchdog.log
```

Then disconnect the laptop from the phone, wait two minutes, reconnect over
ADB, and check the heartbeat/log again. This validates survival of an ADB
disconnect without intentionally interrupting the server. It does not prove
survival of a future Android app kill. A controlled crash-recovery test must
be scheduled separately with a working ADB fallback and saved application work.

Stop it without killing unrelated processes:

```powershell
adb shell sh /data/local/tmp/android-termux-watchdog.sh stop
```

## Limits

- The watchdog does not survive reboot. Termux:Boot remains the boot path;
  actual behavior after reboot/unlock must be verified separately.
- Android can terminate the watchdog too; foreground launch can be restricted
  by the OS/lock state. Neither nohup nor setsid guarantees survival.
- Losing Wi-Fi/ADB, rebooting, or device power loss can remove the manual
  fallback. A paired laptop is not a guarantee of a reachable ADB daemon.
- The script does not restore unsaved work, VS Code, or the desktop session.
- No Android policy or process-limit settings are changed by this script.

Sources: [Android exit records](https://developer.android.com/reference/android/app/ApplicationExitInfo),
[wireless ADB](https://developer.android.com/tools/adb#wireless-android11-command-line),
[Termux:Boot](https://github.com/termux/termux-boot).
