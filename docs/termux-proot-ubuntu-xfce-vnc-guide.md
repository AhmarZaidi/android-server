# Termux Ubuntu GUI quick setup

This creates a manually started XFCE desktop in the existing Ubuntu PRoot. It uses a dedicated `desktop` user and exposes VNC only on localhost; remote access goes through SSH.

## Assumptions

- Termux and `proot-distro` are installed.
- The Ubuntu PRoot already exists.
- Termux SSH is reachable on port `8022`.
- Run Termux commands as the normal Termux user, not inside Ubuntu, unless stated otherwise.

## 1. Install the Ubuntu GUI packages

First ensure no other package operation is running:

```bash
pgrep -af 'apt|dpkg' || true
```

Then run:

```bash
proot-distro login ubuntu -- /bin/bash -lc '
apt update &&
apt install -y --no-install-recommends \
  xfce4 \
  xfce4-terminal \
  dbus-x11 \
  tigervnc-standalone-server \
  tigervnc-tools \
  x11-xserver-utils \
  adwaita-icon-theme \
  fonts-dejavu-core
'
```

Do not run `apt upgrade` as part of this setup.

## 2. Create the dedicated desktop user

Enter Ubuntu as root:

```bash
proot-distro login ubuntu
```

Run:

```bash
id desktop >/dev/null 2>&1 || useradd -m -s /bin/bash desktop

install -d -o desktop -g desktop -m 700 \
  /home/desktop/.config/tigervnc \
  /home/desktop/.runtime

exit
```

## 3. Create the VNC password

From Termux:

```bash
proot-distro login ubuntu --user desktop -- tigervncpasswd
```

Enter a VNC password. Answer `n` when asked to create a view-only password.

## 4. Configure the XFCE session

Enter Ubuntu as the desktop user:

```bash
proot-distro login ubuntu --user desktop
```

Run:

```bash
mkdir -p "$HOME/.config/tigervnc" "$HOME/.runtime"
chmod 700 "$HOME/.runtime"

tee "$HOME/.config/tigervnc/xstartup" >/dev/null <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="$HOME/.runtime"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
exec dbus-launch --exit-with-session startxfce4
EOF

chmod 700 "$HOME/.config/tigervnc/xstartup"
exit
```

## 5. Create the GUI start command

Back in Termux:

```bash
mkdir -p "$HOME/.local/bin"

tee "$HOME/.local/bin/ubuntu-gui-start" >/dev/null <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
set -eu

gui_state="$HOME/.local/state/ubuntu-gui"
gui_vnc_dir="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/home/desktop/.config/tigervnc"

mkdir -p "$gui_state"

tcp_ready() {
  timeout 3 bash -c \
    'exec 3<>/dev/tcp/127.0.0.1/5901' \
    >/dev/null 2>&1
}

if tcp_ready; then
  echo "Ubuntu GUI is already running at localhost:5901"
  exit 0
fi

: >"$gui_state/server.log"

timeout 10 proot-distro login ubuntu --user desktop -- \
  tigervncserver -list -cleanstale >/dev/null 2>&1 || true

nohup proot-distro login ubuntu \
  --user desktop \
  --no-kill-on-exit \
  --no-sysvipc \
  -- /bin/bash -lc '
export XDG_RUNTIME_DIR="$HOME/.runtime"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

exec tigervncserver :1 \
  -localhost yes \
  -geometry 1600x900 \
  -depth 24 \
  -desktop "Sanders Ubuntu"
' >"$gui_state/server.log" 2>&1 </dev/null &

sleep 12

if tcp_ready; then
  echo "Ubuntu GUI is running at localhost:5901"
else
  echo "Ubuntu GUI failed to start."
  tail -n 40 "$gui_state/server.log"

  for gui_log in "$gui_vnc_dir"/*.log; do
    [ -f "$gui_log" ] && tail -n 60 "$gui_log"
  done

  exit 1
fi
EOF

chmod 700 "$HOME/.local/bin/ubuntu-gui-start"
```

## 6. Create the GUI stop command

```bash
tee "$HOME/.local/bin/ubuntu-gui-stop" >/dev/null <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh

timeout 15 proot-distro login ubuntu --user desktop -- \
  tigervncserver -kill :1 >/dev/null 2>&1 || true

sleep 2

if timeout 2 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5901' >/dev/null 2>&1; then
  echo "Ubuntu GUI is still listening on localhost:5901"
  exit 1
fi

echo "Ubuntu GUI stopped"
EOF

chmod 700 "$HOME/.local/bin/ubuntu-gui-stop"
```

Add aliases:

```bash
sed -i '/^alias ugui=/d;/^alias uguistop=/d' "$HOME/.zshrc"

printf '%s\n' \
  "alias ugui='\$HOME/.local/bin/ubuntu-gui-start'" \
  "alias uguistop='\$HOME/.local/bin/ubuntu-gui-stop'" \
  >> "$HOME/.zshrc"

source "$HOME/.zshrc"
```

## 7. Start the GUI

```bash
ugui
```

Expected output:

```text
Ubuntu GUI is running at localhost:5901
```

## 8. Install the Windows viewer

Download the 64-bit standalone TigerVNC Viewer from the official TigerVNC files page:

<https://sourceforge.net/projects/tigervnc/files/stable/>

Choose the latest `vncviewer64-<version>.exe`. This is portable and does not install a Windows service.

## 9. Create the encrypted Windows tunnel

Keep this PowerShell window open:

```powershell
ssh -N -L 5901:127.0.0.1:5901 -p 8022 u0_a468@sanders.lan
```

In TigerVNC Viewer, connect to:

```text
127.0.0.1::5901
```

The double colon specifies an explicit VNC port. Enter the VNC password created earlier. A warning that VNC itself is unencrypted is expected because the SSH tunnel encrypts the connection.

## 10. Useful TigerVNC shortcuts

- Fullscreen toggle: `Ctrl+Alt+Enter`
- Viewer control menu: `Ctrl+Alt+M`
- Send system keys to Ubuntu: `Ctrl+Alt+G`
- Release keyboard capture: press `Ctrl+Alt`

## 11. Stop the GUI

Close the VNC Viewer, press `Ctrl+C` in the Windows tunnel, and run in Termux:

```bash
uguistop
```

## Optional lightweight appearance

Install the smaller theme/font components first:

```bash
proot-distro login ubuntu -- /bin/bash -lc '
apt install -y --no-install-recommends \
  arc-theme \
  fonts-inter \
  xfce4-whiskermenu-plugin
'
```

Papirus is attractive at runtime but contains more than 43,000 small files and can take a long time to install or generate its icon cache under PRoot. Install it only if desired:

```bash
proot-distro login ubuntu -- /bin/bash -lc '
apt install -y --no-install-recommends papirus-icon-theme
'
```

In XFCE:

- **Appearance → Style:** `Arc-Dark`
- **Appearance → Icons:** `Papirus-Dark`, if installed
- **Appearance → Fonts:** `Inter Regular 10`
- **Desktop Settings → Background:** `/usr/share/backgrounds/xfce/xfce-cp-dark.svg`
- Disable compositing under **Window Manager Tweaks → Compositor** if the session feels slow.

## Application Finder shortcut

1. In **Window Manager → Keyboard**, clear the existing `Alt+Space` binding for the window operations menu.
2. In **Keyboard → Application Shortcuts**, add:

```text
xfce4-appfinder --collapsed
```

3. Assign `Alt+Space`.

In TigerVNC, use `Ctrl+Alt+G` first if Windows captures `Alt+Space`.

## Troubleshooting

### VNC startup log

```bash
tail -n 100 "$HOME/.local/state/ubuntu-gui/server.log"
```

Detailed guest log:

```bash
tail -n 100 \
  "$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/home/desktop/.config/tigervnc/"*.log
```

### Test port 5901 without `ss`

Android may deny the netlink call used by `ss`. Use:

```bash
timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5901' \
  && echo "VNC reachable" \
  || echo "VNC unavailable"
```

### APT lock

Never delete an APT lock file. Check the owning process:

```bash
pgrep -af 'apt|dpkg|gtk-update-icon-cache'
```

Wait for it to finish. If an interrupted installation has exited, recover with:

```bash
proot-distro login ubuntu -- /bin/bash -lc '
dpkg --configure -a && apt-get -f install -y
'
```

### Safety notes

- VNC binds only to `127.0.0.1`; do not expose port `5901` directly to the LAN.
- Start and stop are manual and do not modify the existing SSH, Tuvu, battery alert, or status-listener services.
- Do not use `proot-distro kill ubuntu` to stop the GUI because it would also stop other processes running in the same Ubuntu PRoot.
