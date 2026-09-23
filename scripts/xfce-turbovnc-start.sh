#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu"
readonly display_number="5"
readonly vnc_port="5905"
readonly state_dir="$HOME/.local/state/ubuntu-turbovnc"
readonly guest_root="$PREFIX/var/lib/proot-distro/installed-rootfs/$distro_alias"
readonly server="$guest_root/opt/TurboVNC/bin/vncserver"

if [ ! -x "$server" ]; then
    printf '%s\n' \
        "TurboVNC is not installed in the Ubuntu environment." \
        "Run scripts/install-xfce-turbovnc.sh from inside Ubuntu first." >&2
    exit 1
fi

tcp_ready() {
    timeout 3 bash -c \
        "exec 3<>/dev/tcp/127.0.0.1/${vnc_port}" \
        >/dev/null 2>&1
}

if tcp_ready; then
    printf '%s\n' \
        "TurboVNC XFCE is already running at localhost:$vnc_port" \
        "Display: :$display_number"
    exit 0
fi

mkdir -p "$state_dir"
: >"$state_dir/server.log"

nohup proot-distro login "$distro_alias" \
    --shared-tmp \
    --user desktop \
    --no-kill-on-exit \
    --no-sysvipc \
    -- /bin/bash -lc '
export XDG_RUNTIME_DIR="$HOME/.runtime-turbovnc"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

exec /opt/TurboVNC/bin/vncserver :5 \
  -fg \
  -localhost \
  -geometry 1280x720 \
  -depth 24 \
  -wm xfce \
  -securitytypes VNC \
  -rfbauth "$HOME/.vnc/passwd" \
  -name "Sanders Ubuntu XFCE TurboVNC"
' >"$state_dir/server.log" 2>&1 </dev/null &

printf '%s\n' "$!" >"$state_dir/wrapper.pid"

for _attempt in $(seq 1 30); do
    if tcp_ready; then
        printf '%s\n' \
            "TurboVNC XFCE is running at localhost:$vnc_port" \
            "Display: :$display_number (1280x720, 24-bit)" \
            "TigerVNC :1 / port 5901 was not modified."
        exit 0
    fi
    sleep 1
done

printf '%s\n' "TurboVNC XFCE failed to start." >&2
tail -n 100 "$state_dir/server.log" >&2 || true
exit 1
