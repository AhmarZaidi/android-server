#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu-gnome-2404"
readonly x_display="4"
readonly rfb_port="5904"
readonly software_vnc_port="5903"
readonly geometry="${GNOME_X11_GEOMETRY:-1280x720}"
readonly termux_prefix="/data/data/com.termux/files/usr"
readonly x_socket="${termux_prefix}/tmp/.X11-unix/X${x_display}"
readonly virgl_socket="${termux_prefix}/tmp/.virgl_test"
readonly state_dir="$HOME/.local/state/gnome-shell-termux-x11"

mkdir -p "$state_dir"

tcp_ready() {
    local port="$1"
    timeout 2 bash -c "exec 3<>/dev/tcp/127.0.0.1/${port}" \
        >/dev/null 2>&1
}

if tcp_ready "$software_vnc_port"; then
    printf '%s\n' \
        "The software VNC session is running on port $software_vnc_port." \
        "Stop it first with: ugnomefullstop" >&2
    exit 1
fi

if tcp_ready "$rfb_port"; then
    printf '%s\n' "Accelerated GNOME is already reachable at localhost:$rfb_port"
    exit 0
fi

if [ ! -s "$state_dir/preferences.before" ]; then
    termux-x11-preference list >"$state_dir/preferences.before"
fi
termux-x11-preference \
    displayResolutionMode:custom \
    "displayResolutionCustom:$geometry" \
    displayStretch:false >/dev/null

: >"$state_dir/termux-x11.log"
: >"$state_dir/virgl.log"
: >"$state_dir/gnome.log"
: >"$state_dir/x11vnc.log"

if ! pgrep -f '(^|/)virgl_test_server_android([[:space:]]|$)' \
    >/dev/null 2>&1; then
    rm -f "$virgl_socket"
    nohup virgl_test_server_android --no-fork \
        >"$state_dir/virgl.log" 2>&1 </dev/null &
fi

for _attempt in $(seq 1 10); do
    if pgrep -f '(^|/)virgl_test_server_android([[:space:]]|$)' \
        >/dev/null 2>&1 && [ -S "$virgl_socket" ]; then
        break
    fi
    sleep 1
done

if [ ! -S "$virgl_socket" ]; then
    printf '%s\n' "VirGL did not create $virgl_socket" >&2
    tail -n 80 "$state_dir/virgl.log" >&2 || true
    exit 1
fi

if [ ! -S "$x_socket" ]; then
    nohup termux-x11 ":${x_display}" -ac -noreset \
        >"$state_dir/termux-x11.log" 2>&1 </dev/null &
    printf '%s\n' "$!" >"$state_dir/termux-x11.pid"
fi

for _attempt in $(seq 1 15); do
    [ -S "$x_socket" ] && break
    sleep 1
done

if [ ! -S "$x_socket" ]; then
    printf '%s\n' "Termux:X11 did not create display :$x_display" >&2
    tail -n 100 "$state_dir/termux-x11.log" >&2 || true
    exit 1
fi

am start --user 0 -n com.termux.x11/.MainActivity >/dev/null 2>&1 || true

nohup proot-distro login "$distro_alias" \
    --shared-tmp \
    --user desktop \
    --no-kill-on-exit \
    --no-sysvipc \
    -- /bin/bash -lc "
export DISPLAY=:${x_display}
export XDG_RUNTIME_DIR=\"\$HOME/.runtime-gnome-shell-x11\"
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=\"ubuntu:GNOME\"
export XDG_SESSION_DESKTOP=ubuntu
export DESKTOP_SESSION=ubuntu
export GNOME_SHELL_SESSION_MODE=ubuntu
export GDK_BACKEND=x11
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
export MESA_GLSL_VERSION_OVERRIDE=400
unset LIBGL_ALWAYS_SOFTWARE
mkdir -p \"\$XDG_RUNTIME_DIR\"
chmod 700 \"\$XDG_RUNTIME_DIR\"
exec dbus-run-session -- \"\$HOME/.local/bin/gnome-shell-proot-session\"
" >"$state_dir/gnome.log" 2>&1 </dev/null &
printf '%s\n' "$!" >"$state_dir/gnome.pid"

sleep 12

nohup proot-distro login "$distro_alias" \
    --shared-tmp \
    --user desktop \
    --no-kill-on-exit \
    --no-sysvipc \
    -- /bin/bash -lc "
exec x11vnc \
  -display :${x_display} \
  -rfbport ${rfb_port} \
  -rfbauth \"\$HOME/.vnc/passwd\" \
  -localhost \
  -forever \
  -shared \
  -noxdamage \
  -repeat \
  -quiet
" >"$state_dir/x11vnc.log" 2>&1 </dev/null &
printf '%s\n' "$!" >"$state_dir/x11vnc.pid"

for _attempt in $(seq 1 20); do
    if tcp_ready "$rfb_port"; then
        sleep 5
        if tcp_ready "$rfb_port"; then
            printf '%s\n' \
                "Accelerated GNOME is running at localhost:$rfb_port" \
                "Display path: GNOME -> VirGL -> Termux:X11 -> x11vnc"
            exit 0
        fi
        break
    fi
    sleep 1
done

printf '%s\n' "Accelerated GNOME failed to start." >&2
for log_file in termux-x11.log virgl.log gnome.log x11vnc.log; do
    printf '\n== %s ==\n' "$log_file" >&2
    tail -n 100 "$state_dir/$log_file" >&2 || true
done
exit 1
