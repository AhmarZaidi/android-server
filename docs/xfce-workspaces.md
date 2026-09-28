# XFCE workspace controls

Run from a terminal **inside the running XFCE desktop**, as `desktop`, without sudo:

```bash
cd ~/Coding/android-server
python3 scripts/xfce-workspaces.py apply
```

The script uses the live XFConf settings service, so no logout or VNC restart is
needed. It saves only the settings it changes in
`~/.local/state/android-server/xfce-workspaces.json` before applying them. Repeating
apply does not overwrite that baseline. It leaves workspace count, names,
compositing, resolution, and existing shortcuts unchanged.

## Controls

| Action | Control |
| --- | --- |
| Move focused window to previous/next workspace (added) | Ctrl+Super+Shift+Left/Right |
| Move focused window to previous/next workspace (existing) | Ctrl+Alt+Home/End |
| Switch workspace (existing on this machine) | Ctrl+Super+Left/Right |
| Move a window with the mouse | Drag its title bar across the left/right screen edge; pause at the edge |
| Move to a chosen workspace | Right-click title bar → Move to Another Workspace |
| Visual workspace switching/movement | Click a panel workspace miniature; drag a miniature window into another workspace |
| Add/remove workspaces (existing) | Alt+Insert / Alt+Delete |
| Name workspaces or set count | Settings → Workspaces, or `xfwm4-workspace-settings` |

Super is the Windows key. Windows/viewer shortcut interception can prevent Super
combinations from reaching XFCE; the Ctrl+Alt+Home/End shortcuts and title-bar menu
provide alternatives. Removing a workspace relocates its windows to a remaining
workspace; it does not close the applications.

The original panel pager showed workspace names only. Miniature mode exposes its
window drag-and-drop interface. At the current 26-pixel panel height these targets
are small; use the keyboard or title-bar menu when that is easier.

`activate_action=none` replaces `bring`: an existing window requesting activation
stays on its workspace, and XFWM does not switch you to it. Links can still open
tabs in that existing browser. This is window-manager activation policy, not a
rule forcing every newly created window onto a specific workspace; applications
that explicitly move themselves can behave differently.

## Rollback

Inside an XFCE terminal:

```bash
cd ~/Coding/android-server
python3 scripts/xfce-workspaces.py restore
```

This restores only the saved properties and removes the added shortcut properties
if they did not previously exist. It refuses to overwrite later edits to those
properties. Unrelated desktop settings are untouched. Keep the JSON until you are
satisfied with the changes; it stays outside Git because it contains local state.

## Full-screen overview option

[xfdashboard](https://docs.xfce.org/apps/xfdashboard/start) provides a GNOME/Mission
Control style application overview for XFCE. It was not installed at inspection;
the configured Ubuntu repository offers version 1.0.0-0ubuntu5 for ARM64. It uses
Clutter and supports live windows through XComposite/XDamage, so responsiveness
and rendering in this PRoot/VNC setup still need a separate trial. It is not
necessary for the controls above, and this change does not install or autostart it.

A trial should start with an explicit shortcut such as Super+Space and a manual
launch, with no compositor/window-manager replacement. Bare Super needs careful
handling so existing Super combinations keep working. Exact GNOME-style top-row
layout and dynamic workspace creation are not promised by this configuration.
Building our own overview is more maintenance than using the existing pager or
testing xfdashboard.

References: [XFCE activation policy](https://wiki.xfce.org/faq),
[workspace switcher](https://docs.xfce.org/xfce/xfce4-panel/4.18/pager).
