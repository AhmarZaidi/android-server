#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

readonly distro_alias="ubuntu"
readonly termux_prefix="/data/data/com.termux/files/usr"
readonly rootfs_dir="${termux_prefix}/var/lib/proot-distro/installed-rootfs/${distro_alias}"
readonly script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"

tracer_pid=$(awk '/^TracerPid:/ { print $2 }' "/proc/$$/status")
if [ "${tracer_pid:-0}" != 0 ]; then
    tracer_name=$(awk '/^Name:/ { print $2 }' "/proc/${tracer_pid}/status")
    if [ "$tracer_name" = "proot" ]; then
        printf '%s\n' "Run this script from native Termux, outside PRoot." >&2
        exit 1
    fi
fi

if [ "${PREFIX:-}" != "$termux_prefix" ]; then
    printf '%s\n' "Run this script from native Termux, outside PRoot." >&2
    exit 1
fi

if [ ! -d "$rootfs_dir" ]; then
    printf '%s\n' "Existing Ubuntu environment not found: $rootfs_dir" >&2
    exit 1
fi

printf '%s\n' "Recording package and XFCE startup baselines"
proot-distro login "$distro_alias" --shared-tmp -- /bin/bash -s <<'GUEST_ROOT'
set -euo pipefail

readonly state_dir="/home/desktop/.local/state/gnome-flashback-trial/rollback"
install -d -o desktop -g desktop -m 700 "$state_dir"

if [ ! -f "$state_dir/packages-before.tsv" ]; then
    dpkg-query -W -f='${binary:Package}\t${Version}\n' \
        >"$state_dir/packages-before.tsv"
    apt-mark showmanual | sort >"$state_dir/manual-packages-before.txt"
    apt-get -s --no-install-recommends install gnome-session-flashback \
        >"$state_dir/planned-install.txt"
    if [ -f /home/desktop/.config/tigervnc/xstartup ]; then
        cp -p /home/desktop/.config/tigervnc/xstartup \
            "$state_dir/xstartup-xfce.before-gnome"
    fi
    chown -R desktop:desktop "$state_dir"
fi

export DEBIAN_FRONTEND=noninteractive
dpkg --configure -a
apt-get install -y --no-install-recommends gnome-session-flashback

install -d -o desktop -g desktop -m 700 \
    /home/desktop/.config/tigervnc \
    /home/desktop/.local/bin \
    /home/desktop/.runtime-gnome
GUEST_ROOT

printf '%s\n' "Creating a GNOME-only VNC startup without changing XFCE"
proot-distro login "$distro_alias" --shared-tmp --user desktop -- /bin/bash -s <<'GUEST_USER'
set -euo pipefail

tee "$HOME/.local/bin/gnome-flashback-proot-session" >/dev/null <<'SESSION'
#!/bin/bash
set -u

child_pids=()
cleaned_up=0

start_component() {
    "$@" &
    child_pids+=("$!")
}

cleanup() {
    [ "$cleaned_up" -eq 0 ] || return 0
    cleaned_up=1
    if [ "${#child_pids[@]}" -gt 0 ]; then
        kill "${child_pids[@]}" >/dev/null 2>&1 || true
        wait "${child_pids[@]}" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT HUP INT TERM

start_component /usr/libexec/gsd-xsettings
start_component /usr/libexec/gsd-keyboard
start_component gnome-flashback
sleep 1
start_component metacity --replace
sleep 1

gnome-panel &
panel_pid=$!
child_pids+=("$panel_pid")
wait "$panel_pid"
SESSION
chmod 700 "$HOME/.local/bin/gnome-flashback-proot-session"

tee "$HOME/.config/tigervnc/xstartup-gnome" >/dev/null <<'XSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="$HOME/.runtime-gnome"
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP="GNOME-Flashback:GNOME"
export XDG_SESSION_DESKTOP=gnome-flashback-metacity
export DESKTOP_SESSION=gnome-flashback-metacity
export GDK_BACKEND=x11
export LIBGL_ALWAYS_SOFTWARE=1
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
exec dbus-launch --exit-with-session \
    "$HOME/.local/bin/gnome-flashback-proot-session"
XSTARTUP
chmod 700 "$HOME/.config/tigervnc/xstartup-gnome"
GUEST_USER

install -d -m 700 "$HOME/.local/bin"
install -m 700 "$script_dir/gnome-flashback-shared-start.sh" "$HOME/.local/bin/ugnome"
install -m 700 "$script_dir/gnome-flashback-shared-stop.sh" "$HOME/.local/bin/ugnomestop"

printf '%s\n' \
    "Shared GNOME Flashback trial is ready." \
    "XFCE remains configured on :1 / port 5901." \
    "GNOME starts with: ugnome"
