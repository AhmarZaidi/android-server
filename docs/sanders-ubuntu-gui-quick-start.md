# Sanders Ubuntu GUI — daily quick start

Use this after the one-time setup is complete.

## Start

### 1. On the server phone in Termux

```bash
ugui
```

Expected:

```text
Ubuntu GUI is running at localhost:5901
```

If it is already running, this is also normal:

```text
Ubuntu GUI is already running at localhost:5901
```

### 2. On Windows

Open PowerShell and run:

```powershell
ssh -N -L 5901:127.0.0.1:5901 -p 8022 u0_a468@sanders.lan
```

No output is expected. Keep this PowerShell window open.

### 3. Open TigerVNC Viewer

Connect to:

```text
127.0.0.1::5901
```

Enter the VNC password.

## Useful shortcuts

- Fullscreen: `Ctrl+Alt+Enter`
- TigerVNC menu: `Ctrl+Alt+M`
- Send Windows/system shortcuts to Ubuntu: `Ctrl+Alt+G`
- Release keyboard capture: press `Ctrl+Alt`
- Ubuntu application finder: `Alt+Space`

## Stop

1. Close TigerVNC Viewer.
2. Press `Ctrl+C` in the Windows PowerShell tunnel.
3. In Termux on the phone, run:

```bash
uguistop
```

Expected:

```text
Ubuntu GUI stopped
```

## Quick troubleshooting

### Viewer cannot connect

On the phone:

```bash
ugui
```

On Windows, make sure the SSH tunnel is still running and reconnect TigerVNC to:

```text
127.0.0.1::5901
```

### Verify VNC on the phone

```bash
timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5901' \
  && echo "VNC running" \
  || echo "VNC stopped"
```

### Inspect the startup log

```bash
tail -n 60 "$HOME/.local/state/ubuntu-gui/server.log"
```

Do not expose port `5901` directly. Always connect through the SSH tunnel.
