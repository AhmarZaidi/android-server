# GNOME Flashback in the existing Ubuntu environment

This trial adds GNOME Flashback packages to the existing Ubuntu PRoot while
preserving XFCE as the default VNC session. Both desktops use the existing
`desktop` home directory, applications, projects, and tools.

- XFCE: display `:1`, port `5901`, existing `xstartup`
- GNOME Flashback: display `:2`, port `5902`, separate `xstartup-gnome`

The setup records the installed and manually selected package lists before
installation under:

```text
/home/desktop/.local/state/gnome-flashback-trial/rollback
```

It does not install GDM, change the existing XFCE startup file, run a general
upgrade, or remove packages. Package removal is intentionally not automated;
switching back only requires stopping display `:2` and using XFCE on `:1`.

GNOME 49 expects a systemd user manager, which PRoot does not provide. The
trial starts the essential Flashback components directly in a private D-Bus
session.
