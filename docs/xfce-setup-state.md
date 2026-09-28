# XFCE setup and recovery map

Video/frame-rate optimization is paused. The working desktop is XFCE in the
existing `ubuntu` PRoot as `desktop`, normally TigerVNC `:1` / localhost `5901`,
accessed from Windows over SSH. The repository lives in Ubuntu at
`~/Coding/android-server`; native Termux has a different home directory.

## Reproducible pieces

| Area | Repo files / state |
| --- | --- |
| Base installation, shell and appearance | [Setup guide](termux-proot-ubuntu-xfce-vnc-guide.md) |
| Daily connection | [Quick start](sanders-ubuntu-gui-quick-start.md) |
| TigerVNC performance profiles | [Profile guide](xfce-vnc-performance.md), `scripts/setup-xfce-vnc-profiles.sh`, `scripts/xfce-vnc-{start,stop}.sh` |
| Viewer presets | `config/tigervnc/xfce-{ultra,smooth,sharp}.tigervnc` |
| Workspace fixes and targeted rollback | [Workspace guide](xfce-workspaces.md), `scripts/xfce-workspaces.py` |
| Optional TurboVNC trial | [Trial guide](xfce-turbovnc.md), `scripts/install-xfce-turbovnc.sh` |
| Broader backups | [Backup guide](backup-and-restore.md) |

Native Termux commands `ugui` / `uguistop` use launchers under `~/.local/bin`.
Profiles are ultra (1024×576, 16-bit), smooth (1280×720, 24-bit), balanced
(1600×900, 24-bit, default), and quality (1920×1080, 24-bit). The 60-update ceiling
is not a measured FPS guarantee. Viewer resizing can change the live dimensions.
Keep fullscreen viewing at the preferred resolution; these workspace changes do
not resize the desktop. Compression 0 / JPEG quality 5 was the user's preferred
TigerVNC balance; pure JPEG encoding tested worse than Tight in this session.

XFWM compositing is disabled. A native VirGL server and shell overrides have been
used for OpenGL apps, but that does not establish GPU acceleration for the entire
XFCE desktop or VNC encoding. Chromium launch shortcuts currently disable its
GPU. Do not globally force VirGL as part of unrelated desktop changes.

GNOME Flashback and the separate `ubuntu-gnome-2404` experiments are paused.
Their files can remain installed without running their desktops. TurboVNC has a
separate trial path on `:5` / `5905` but shares the XFCE user's configuration;
do not run both XFCE sessions simultaneously. Repository scripts alone are not
proof that a trial is installed or in use.

## Recovery boundaries

Workspace changes have a per-property rollback, with no desktop restart. Before
changing launcher files, the profile installer saves the first originals under
native Termux `~/.local/state/ubuntu-gui/launcher-backup/`. Restoring these requires
copying the matching `.original` files back to `~/.local/bin/ubuntu-gui-start` and
`ubuntu-gui-stop` while the desktop is stopped; save open work first. Do not
replace XFConf XML while the settings daemon is running: use `xfconf-query` or
the workspace script. Never remove packages with an unreviewed `autoremove` as a
rollback strategy.

These notes and scripts reproduce selected settings; they are not a full backup
of the user's home or a guarantee against every application-specific regression.
