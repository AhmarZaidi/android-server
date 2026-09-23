#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly gui_state="$HOME/.local/state/gnome-flashback-trial"
readonly guest_vnc_dir="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/home/desktop/.config/tigervnc"

mkdir -p "$gui_state"

tcp_ready() {
    timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5902' >/dev/null 2>&1
}

if tcp_ready; then
    printf '%s\n' "GNOME Flashback is already reachable at localhost:5902"
    exit 0
fi

: >"$gui_state/server.log"

nohup proot-distro login ubuntu \
    --shared-tmp \
    --user desktop \
    --no-kill-on-exit \
    --no-sysvipc \
    -- /bin/bash -lc '
export XDG_RUNTIME_DIR="$HOME/.runtime-gnome"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

exec tigervncserver :2 \
  -localhost yes \
  -geometry 1920x1080 \
  -depth 24 \
  -extension MIT-SHM \
  -xstartup "$HOME/.config/tigervnc/xstartup-gnome" \
  -desktop "Sanders GNOME Flashback trial"
' >"$gui_state/server.log" 2>&1 </dev/null &

for _attempt in $(seq 1 20); do
    if tcp_ready; then
        printf '%s\n' "GNOME Flashback is running at localhost:5902"
        exit 0
    fi
    sleep 1
done

printf '%s\n' "GNOME Flashback failed to start." >&2
tail -n 60 "$gui_state/server.log" >&2 || true
for guest_log in "$guest_vnc_dir"/*.log; do
    [ -f "$guest_log" ] && tail -n 80 "$guest_log" >&2
done
exit 1
