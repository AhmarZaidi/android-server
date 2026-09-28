#!/usr/bin/env bash
set -euo pipefail

readonly version="3.3"
readonly rpm_name="turbovnc-${version}.aarch64.rpm"
readonly rpm_url="https://github.com/TurboVNC/turbovnc/releases/download/${version}/${rpm_name}"
readonly rpm_sha256="7df6a1bb872785976757fa000a1213e9fee29352308e75cd0b223ac88165183e"
readonly install_dir="/opt/TurboVNC"
readonly marker="$install_dir/.android-server-managed"
readonly termux_home="/data/data/com.termux/files/home"
readonly script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"

if [ ! -r /etc/os-release ] || ! grep -q '^ID=ubuntu$' /etc/os-release; then
    printf '%s\n' "Run this installer inside the existing Ubuntu PRoot." >&2
    exit 1
fi

if [ "$(dpkg --print-architecture)" != "arm64" ]; then
    printf '%s\n' "This installer is pinned to the official ARM64 package." >&2
    exit 1
fi

for required_file in xfce-turbovnc-start.sh xfce-turbovnc-stop.sh; do
    [ -f "$script_dir/$required_file" ] || {
        printf '%s\n' "Missing required file: $script_dir/$required_file" >&2
        exit 1
    }
done

if [ -d "$install_dir" ] && [ ! -f "$marker" ]; then
    printf '%s\n' \
        "$install_dir already exists and was not created by this installer." \
        "It has been left untouched." >&2
    exit 1
fi

sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl cpio rpm2cpio

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

curl -fL --retry 3 -o "$work_dir/$rpm_name" "$rpm_url"
printf '%s  %s\n' "$rpm_sha256" "$work_dir/$rpm_name" | sha256sum -c -

mkdir -p "$work_dir/root"
(
    cd "$work_dir/root"
    rpm2cpio "$work_dir/$rpm_name" | cpio -idm --quiet
)

staged_install="$work_dir/root/opt/TurboVNC"
if [ ! -x "$staged_install/bin/vncserver" ] \
    || [ ! -x "$staged_install/bin/Xvnc" ]; then
    printf '%s\n' "The verified package did not contain the expected server files." >&2
    exit 1
fi

if [ -d "$install_dir" ]; then
    installed_version="$($install_dir/bin/Xvnc -version 2>&1 | head -n 1 || true)"
    if printf '%s' "$installed_version" | grep -q "$version"; then
        printf '%s\n' "TurboVNC $version is already installed; refreshing launchers."
    else
        printf '%s\n' \
            "A different managed TurboVNC version already exists at $install_dir." \
            "It has been left untouched." >&2
        exit 1
    fi
else
    sudo cp -a "$staged_install" "$install_dir"
    printf '%s\n' "version=$version" | sudo tee "$marker" >/dev/null
fi

for config_name in turbovncserver.conf turbovncserver-security.conf; do
    staged_config="$work_dir/root/etc/$config_name"
    target_config="/etc/$config_name"
    if [ -f "$staged_config" ] && [ ! -e "$target_config" ]; then
        sudo install -m 644 "$staged_config" "$target_config"
    fi
done

mkdir -p "$HOME/.vnc"
chmod 700 "$HOME/.vnc"
if [ ! -f "$HOME/.vnc/passwd" ]; then
    if [ -f "$HOME/.config/tigervnc/passwd" ]; then
        install -m 600 "$HOME/.config/tigervnc/passwd" "$HOME/.vnc/passwd"
    else
        printf '%s\n' "Create a password for the TurboVNC trial."
        "$install_dir/bin/vncpasswd" "$HOME/.vnc/passwd"
    fi
fi

cat > "$HOME/.vnc/xstartup.turbovnc" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="$HOME/.runtime-turbovnc"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
exec dbus-launch --exit-with-session startxfce4
EOF
chmod 700 "$HOME/.vnc/xstartup.turbovnc"

native_bin="$termux_home/.local/bin"
native_state="$termux_home/.local/state/ubuntu-turbovnc"
mkdir -p "$native_bin" "$native_state/launcher-backup"

for pair in \
    "xfce-turbovnc-start.sh:uturbo" \
    "xfce-turbovnc-stop.sh:uturbostop"; do
    source_name="${pair%%:*}"
    target_name="${pair##*:}"
    target="$native_bin/$target_name"
    backup="$native_state/launcher-backup/$target_name.original"
    if [ -f "$target" ] && [ ! -f "$backup" ]; then
        cp -p "$target" "$backup"
    fi
    install -m 700 "$script_dir/$source_name" "$target"
done

printf '%s\n' \
    "TurboVNC $version is installed as an isolated XFCE trial." \
    "Start it from native Termux with: uturbo" \
    "Stop it with: uturbostop" \
    "It listens only on localhost:5905." \
    "The existing TigerVNC installation and port 5901 were not modified."
