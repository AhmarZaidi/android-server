# XFCE VNC performance profiles

The XFCE desktop runs in TigerVNC's virtual X server. Its perceived smoothness depends mainly on framebuffer size, changed-pixel detection, VNC encoding, Wi-Fi throughput, and client decoding. VirGL can accelerate individual OpenGL applications, but it does not accelerate TigerVNC capture or network encoding.

## Install the launch profiles

Copy this repository's `scripts` directory to native Termux, then run there:

```bash
./setup-xfce-vnc-profiles.sh
```

The installer keeps one backup of the previous launchers under `~/.local/state/ubuntu-gui/launcher-backup/`.

## Profiles

After stopping the current session, start one of:

```bash
ugui ultra     # 1024x576, 16-bit color, highest responsiveness
ugui smooth    # 1280x720, 24-bit color
ugui balanced  # 1600x900, previous resolution and default
ugui quality   # 1920x1080, highest pixel cost
```

All profiles use TigerVNC's 60-update-per-second ceiling and automatic framebuffer comparison. `XFCE_VNC_GEOMETRY`, `XFCE_VNC_DEPTH`, and `XFCE_VNC_FPS` can override the selected values for a test.

The ultra profile processes 36% fewer pixels than smooth and about 59% fewer than balanced. Its 16-bit RGB565 framebuffer further reduces memory bandwidth, with possible color banding on gradients.

## Windows viewer profiles

- `config/tigervnc/xfce-ultra.tigervnc` uses Tight encoding, compression level 0, JPEG quality 5, and a 10 ms pointer interval.
- `config/tigervnc/xfce-smooth.tigervnc` uses Tight encoding with JPEG quality 7.
- `config/tigervnc/xfce-sharp.tigervnc` disables JPEG for crisp text and icons at the cost of more traffic and potentially lower scrolling performance.

Do not add SSH compression (`ssh -C`) to the tunnel. VNC already compresses its framebuffer, and recompressing it adds latency and CPU work.

## Compositing and GPU policy

XFWM compositing is disabled in the current configuration. This removes shadows and opacity effects, but it avoids extra full-screen redraws and gives VNC the best responsiveness. Enabling desktop animations would reduce remote smoothness on this pipeline.

VirGL remains useful for OpenGL programs launched from a shell configured with `GALLIUM_DRIVER=virpipe`. It should stay opt-in for those applications rather than being forced across the entire XFCE session.
