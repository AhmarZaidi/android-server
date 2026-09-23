#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu-gnome-2404"
readonly display_number="3"
readonly vnc_port="5903"
readonly geometry="${GNOME_VNC_GEOMETRY:-1280x720}"
readonly termux_prefix="/data/data/com.termux/files/usr"
readonly rootfs_dir="${termux_prefix}/var/lib/proot-distro/installed-rootfs/${distro_alias}"
readonly virgl_binary="${termux_prefix}/bin/virgl_test_server_android"
readonly virgl_socket="${termux_prefix}/tmp/.virgl_test"
readonly gui_state="$HOME/.local/state/gnome-shell-ubuntu-2404"
readonly guest_vnc_dir="${rootfs_dir}/home/desktop/.vnc"

mkdir -p "$gui_state"

tcp_ready() {
    timeout 3 bash -c \
        "exec 3<>/dev/tcp/127.0.0.1/${vnc_port}" \
        >/dev/null 2>&1
}

terminate_isolated_processes() {
    local signal_name="$1"
    pkill "-$signal_name" -f "$rootfs_dir" >/dev/null 2>&1 || true
}

if tcp_ready; then
    printf '%s\n' "GNOME Shell is already reachable at localhost:$vnc_port"
    exit 0
fi

# A failed PRoot session can leave every daemon alive because the login uses
# --no-kill-on-exit. Clear processes belonging to this dedicated rootfs before
# relaunching. The original Ubuntu/XFCE rootfs has a different path.
terminate_isolated_processes TERM
sleep 2
terminate_isolated_processes KILL

: >"$gui_state/server.log"
: >"$gui_state/virgl.log"

graphics_mode="software"
if [ "${GNOME_VNC_GPU:-0}" = 1 ] && [ -x "$virgl_binary" ]; then
    if ! pgrep -f '(^|/)virgl_test_server_android([[:space:]]|$)' >/dev/null 2>&1; then
        rm -f "$virgl_socket"
        nohup "$virgl_binary" --no-fork >"$gui_state/virgl.log" 2>&1 </dev/null &
    fi

    for _attempt in $(seq 1 10); do
        if pgrep -f '(^|/)virgl_test_server_android([[:space:]]|$)' >/dev/null 2>&1 \
            && [ -S "$virgl_socket" ]; then
            graphics_mode="virgl"
            break
        fi
        sleep 1
    done
fi

printf 'GNOME graphics mode: %s\n' "$graphics_mode"

timeout 10 proot-distro login "$distro_alias" \
    --shared-tmp \
    -- /bin/bash -c \
        'if [ ! -S /run/dbus/system_bus_socket ]; then rmdir /run/systemd/seats 2>/dev/null || true; fi' \
    >/dev/null 2>&1 || true

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
export XDG_RUNTIME_DIR=\"\$HOME/.runtime-gnome-shell\"
export GNOME_GFX_MODE=\"${graphics_mode}\"
mkdir -p \"\$XDG_RUNTIME_DIR\"
chmod 700 \"\$XDG_RUNTIME_DIR\"

exec tigervncserver :${display_number} \\
  -localhost yes \\
  -geometry ${geometry} \\
  -depth 24 \\
  -extension MIT-SHM \\
  -desktop \"Sanders GNOME Shell 46\"
" >"$gui_state/server.log" 2>&1 </dev/null &

for _attempt in $(seq 1 45); do
    if tcp_ready; then
        sleep 8
        if tcp_ready; then
            printf '%s\n' "GNOME Shell is running at localhost:$vnc_port"
            exit 0
        fi
        break
    fi
    sleep 1
done

printf '%s\n' "GNOME Shell failed to start." >&2
tail -n 80 "$gui_state/server.log" >&2 || true

for guest_log in "$guest_vnc_dir"/*.log; do
    [ -f "$guest_log" ] && tail -n 100 "$guest_log" >&2
done

exit 1
