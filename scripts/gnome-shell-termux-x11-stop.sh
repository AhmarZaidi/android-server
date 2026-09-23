#!/data/data/com.termux/files/usr/bin/bash
set -u

readonly distro_alias="ubuntu-gnome-2404"
readonly legacy_rfb_port="5904"
readonly x_display="4"
readonly termux_prefix="/data/data/com.termux/files/usr"
readonly state_dir="$HOME/.local/state/gnome-shell-termux-x11"

timeout 15 proot-distro login "$distro_alias" \
    --shared-tmp \
    --user desktop \
    -- /bin/bash -c \
        "pkill -f 'x11vnc.*-rfbport ${legacy_rfb_port}' 2>/dev/null || true; pkill -f gnome-shell-proot-session 2>/dev/null || true" \
    >/dev/null 2>&1 || true

for pid_file in "$state_dir/x11vnc.pid" "$state_dir/gnome.pid" \
    "$state_dir/termux-x11.pid"; do
    [ -s "$pid_file" ] || continue
    pid=$(cat "$pid_file")
    kill "$pid" >/dev/null 2>&1 || true
    rm -f "$pid_file"
done

am force-stop --user 0 com.termux.x11 >/dev/null 2>&1 || true
rm -f \
    "${termux_prefix}/tmp/.X11-unix/X${x_display}" \
    "${termux_prefix}/tmp/.X${x_display}-lock"

if [ -s "$state_dir/preferences.before" ]; then
    termux-x11-preference <"$state_dir/preferences.before" >/dev/null 2>&1 || true
    rm -f "$state_dir/preferences.before"
fi

printf '%s\n' "Accelerated Termux:X11 GNOME stopped"
