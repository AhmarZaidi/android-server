#!/system/bin/sh
# Run as Android's ADB shell (UID 2000), never inside Termux/PRoot.
PATH=/system/bin:/system/xbin
export PATH
umask 077
state=/data/local/tmp/sanders-watchdog

if [ "$(id -u)" != 2000 ]; then
    echo 'Run this through adb shell, not Termux or Ubuntu.' >&2
    exit 1
fi
mkdir -p "$state" || exit 1

healthy() {
    pidof com.termux >/dev/null 2>&1 && pidof sshd >/dev/null 2>&1
}

recover() {
    # Opening the activity restored SSH on this device previously. Verify again.
    timeout 20 am start --user 0 -n com.termux/com.termux.app.TermuxActivity
    sleep 10
    if healthy; then
        echo 'Termux and sshd processes are present; verify SSH from the client.'
        return 0
    fi
    echo 'Recovery incomplete: Termux or sshd is still absent.' >&2
    return 1
}

case "${1:-}" in
    check)
        echo "Android UID: $(id -u)"
        echo "Termux PID: $(pidof com.termux)"
        echo "sshd PID: $(pidof sshd)"
        if [ -f "$state/heartbeat" ]; then cat "$state/heartbeat"; fi
        healthy
        exit $?
        ;;
    recover)
        recover
        exit $?
        ;;
    stop)
        touch "$state/stop"
        echo 'Stop requested; allow up to 60 seconds.'
        exit 0
        ;;
    watch) ;;
    *) echo "Usage: $0 {check|recover|watch|stop}" >&2; exit 2 ;;
esac

# Kernel releases this lock even if the watchdog is killed.
exec 9>"$state/lock"
flock -n 9 || { echo 'Watchdog already running.' >&2; exit 1; }
rm -f "$state/stop"
log() {
    if [ -f "$state/watchdog.log" ] && [ "$(wc -c < "$state/watchdog.log")" -gt 65536 ]; then
        mv -f "$state/watchdog.log" "$state/watchdog.log.1"
    fi
    printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$state/watchdog.log"
}
log "Started PID $$ as Android shell. No reboot persistence."
misses=0
cooldown=0
while [ ! -f "$state/stop" ]; do
    printf '%s pid=%s\n' "$(date -Iseconds)" "$$" > "$state/heartbeat"
    if healthy; then
        misses=0
    else
        misses=$((misses + 1))
    fi
    if [ "$cooldown" -gt 0 ]; then cooldown=$((cooldown - 1)); fi
    if [ "$misses" -ge 3 ] && [ "$cooldown" -eq 0 ]; then
        log 'Three missing-process checks; saving exit record and reopening Termux.'
        timeout 10 dumpsys activity exit-info com.termux > "$state/last-exit-info.txt" 2>&1
        if recover > "$state/last-recovery.txt" 2>&1; then
            log 'Termux and sshd processes present after launch.'
        else
            log 'Recovery incomplete; inspect last-recovery.txt.'
        fi
        misses=0
        cooldown=10
    fi
    sleep 30
done
log 'Stopped by request.'
