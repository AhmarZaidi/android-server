#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu-gnome-flashback"
readonly display_number="2"
readonly vnc_port="5902"
readonly gui_state="$HOME/.local/state/gnome-flashback-trial"
readonly guest_vnc_dir="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/${distro_alias}/home/desktop/.config/tigervnc"

mkdir -p "$gui_state"

tcp_ready() {
    timeout 3 bash -c \
        "exec 3<>/dev/tcp/127.0.0.1/${vnc_port}" \
        >/dev/null 2>&1
}

if tcp_ready; then
    printf '%s\n' "GNOME Flashback is already reachable at localhost:$vnc_port"
    exit 0
fi

: >"$gui_state/server.log"

timeout 10 proot-distro login "$distro_alias" \
    --shared-tmp \
    --user desktop \
    -- tigervncserver -list -cleanstale >/dev/null 2>&1 || true

nohup proot-distro login "$distro_alias" \
    --shared-tmp \
    --user desktop \
    --no-kill-on-exit \
    --no-sysvipc \
    -- /bin/bash -lc "
export XDG_RUNTIME_DIR=\"\$HOME/.runtime\"
mkdir -p \"\$XDG_RUNTIME_DIR\"
chmod 700 \"\$XDG_RUNTIME_DIR\"

exec tigervncserver :${display_number} \\
  -localhost yes \\
  -geometry 1920x1080 \\
  -depth 24 \\
  -extension MIT-SHM \\
  -desktop \"Sanders GNOME Flashback trial\"
" >"$gui_state/server.log" 2>&1 </dev/null &

for _attempt in $(seq 1 20); do
    if tcp_ready; then
        printf '%s\n' "GNOME Flashback is running at localhost:$vnc_port"
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
