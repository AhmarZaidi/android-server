#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu"
readonly display_number="1"
readonly vnc_port="5901"
readonly gui_state="$HOME/.local/state/ubuntu-gui"
readonly guest_vnc_dir="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/home/desktop/.config/tigervnc"

profile="${1:-balanced}"
case "$profile" in
    smooth)
        geometry="1280x720"
        ;;
    balanced)
        geometry="1600x900"
        ;;
    quality)
        geometry="1920x1080"
        ;;
    *)
        printf '%s\n' \
            "Unknown XFCE VNC profile: $profile" \
            "Use: ugui [smooth|balanced|quality]" >&2
        exit 2
        ;;
esac

geometry="${XFCE_VNC_GEOMETRY:-$geometry}"
frame_rate="${XFCE_VNC_FPS:-60}"

mkdir -p "$gui_state"

tcp_ready() {
    timeout 3 bash -c \
        "exec 3<>/dev/tcp/127.0.0.1/${vnc_port}" \
        >/dev/null 2>&1
}

if tcp_ready; then
    running_profile="unknown"
    [ -s "$gui_state/profile" ] && running_profile=$(cat "$gui_state/profile")
    printf '%s\n' \
        "Ubuntu XFCE is already running at localhost:$vnc_port" \
        "Active profile: $running_profile"
    exit 0
fi

: >"$gui_state/server.log"
printf '%s (%s, %s fps max)\n' "$profile" "$geometry" "$frame_rate" \
    >"$gui_state/profile"

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
  -geometry ${geometry} \\
  -depth 24 \\
  -FrameRate ${frame_rate} \\
  -CompareFB 2 \\
  -desktop \"Sanders Ubuntu XFCE (${profile})\"
" >"$gui_state/server.log" 2>&1 </dev/null &

for _attempt in $(seq 1 30); do
    if tcp_ready; then
        printf '%s\n' \
            "Ubuntu XFCE is running at localhost:$vnc_port" \
            "Profile: $profile ($geometry, ${frame_rate} fps max)"
        exit 0
    fi
    sleep 1
done

printf '%s\n' "Ubuntu XFCE failed to start." >&2
tail -n 60 "$gui_state/server.log" >&2 || true
for guest_log in "$guest_vnc_dir"/*.log; do
    [ -f "$guest_log" ] && tail -n 80 "$guest_log" >&2
done
exit 1
