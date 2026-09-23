#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu-gnome-2404"
readonly display_number="3"
readonly vnc_port="5903"
readonly geometry="${GNOME_VNC_GEOMETRY:-1280x720}"
readonly virgl_binary="/data/data/com.termux/files/usr/bin/virgl_test_server_android"
readonly virgl_socket="/data/data/com.termux/files/usr/tmp/.virgl_test"
readonly gui_state="$HOME/.local/state/gnome-shell-ubuntu-2404"
readonly guest_vnc_dir="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/${distro_alias}/home/desktop/.vnc"

mkdir -p "$gui_state"

tcp_ready() {
    timeout 3 bash -c \
        "exec 3<>/dev/tcp/127.0.0.1/${vnc_port}" \
        >/dev/null 2>&1
}

if tcp_ready; then
    printf '%s\n' "GNOME Shell is already reachable at localhost:$vnc_port"
    exit 0
fi

: >"$gui_state/server.log"
: >"$gui_state/virgl.log"

graphics_mode="software"
if [ "${GNOME_VNC_GPU:-0}" = 1 ] && [ -x "$virgl_binary" ]; then
    if ! pgrep -f '(^|/)virgl_test_server_android([[:space:]]|$)' \
        >/dev/null 2>&1; then
        rm -f "$virgl_socket"
        nohup "$virgl_binary" --no-fork \
            >"$gui_state/virgl.log" 2>&1 </dev/null &
    fi

    for _attempt in $(seq 1 10); do
        if pgrep -f '(^|/)virgl_test_server_android([[:space:]]|$)' \
            >/dev/null 2>&1 && [ -S "$virgl_socket" ]; then
            graphics_mode="virgl"
            break
        fi
        sleep 1
    done
fi

printf 'GNOME graphics mode: %s\n' "$graphics_mode"

# GNOME Shell selects logind merely when this empty systemd runtime marker
# exists. PRoot has no system bus or logind, so remove the marker and let
# GNOME use its built-in non-systemd login manager.
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
        # GNOME starts after the VNC listener. Require the port to survive its
        # initialization window before reporting a usable desktop.
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
