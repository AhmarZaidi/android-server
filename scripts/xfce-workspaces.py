#!/usr/bin/env python3
"""Apply/restore a small, backed-up XFCE workspace profile in the live session."""
import argparse
import json
import os
from pathlib import Path
import subprocess

STATE = Path.home() / '.local/state/android-server/xfce-workspaces.json'


def query(channel, *args):
    return subprocess.check_output(
        ['xfconf-query', '-c', channel, *args], text=True, timeout=10).strip()


def read(channel, prop):
    if prop not in query(channel, '-l').splitlines():
        return None
    return query(channel, '-p', prop)


def write(item, value):
    channel, prop, kind = item['channel'], item['property'], item['type']
    current = read(channel, prop)
    if current == value:
        return
    if value is None:
        query(channel, '-p', prop, '-r')
    elif current is None:
        query(channel, '-p', prop, '-n', '-t', kind, '-s', value)
    else:
        query(channel, '-p', prop, '-s', value)
    if read(channel, prop) != value:
        raise RuntimeError(f'Could not verify {channel}:{prop}')


def profile():
    values = [
        ('xfwm4', '/general/activate_action', 'string', 'none'),
        ('xfwm4', '/general/wrap_windows', 'bool', 'true'),
    ]
    # Keep existing workspace-switch keys and add matching move-window keys.
    for direction, action in [('Left', 'prev'), ('Right', 'next')]:
        key = f'<Primary><Shift><Super>{direction}'
        prop = f'/xfwm4/custom/{key}'
        target = f'move_window_{action}_workspace_key'
        commands = read('xfce4-keyboard-shortcuts', f'/commands/custom/{key}')
        existing = read('xfce4-keyboard-shortcuts', prop)
        if commands is not None or existing not in (None, target):
            raise RuntimeError(f'Shortcut already assigned: {key}; nothing changed')
        values.append(('xfce4-keyboard-shortcuts', prop, 'string', target))
    # Discover the existing pager instead of assuming a plugin ID on new installs.
    for prop in query('xfce4-panel', '-l').splitlines():
        if prop.startswith('/plugins/plugin-') and prop.count('/') == 2:
            if read('xfce4-panel', prop) == 'pager':
                values.append(('xfce4-panel', prop + '/miniature-view', 'bool', 'true'))
    return [dict(channel=c, property=p, type=t, new=v, old=read(c, p))
            for c, p, t, v in values]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['apply', 'restore'])
    args = parser.parse_args()
    if not os.environ.get('DISPLAY') or not os.environ.get('DBUS_SESSION_BUS_ADDRESS'):
        parser.error('Run inside an XFCE terminal as desktop, without sudo.')
    # A failed bus connection must never be mistaken for an absent setting.
    query('xfwm4', '-l')
    if args.action == 'apply':
        if STATE.exists():
            items = json.loads(STATE.read_text())
            if all(read(i['channel'], i['property']) == i['new'] for i in items):
                print(f'Already applied. Rollback saved at {STATE}')
                return
            raise RuntimeError('Existing backup with changed settings; restore first.')
        items = profile()
        STATE.parent.mkdir(parents=True, exist_ok=True)
        # Save all originals before the first live change; never overwrite a backup.
        fd = os.open(STATE, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump(items, stream, indent=2)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            for item in items:
                write(item, item['new'])
        except Exception:
            for item in reversed(items):
                write(item, item['old'])
            STATE.unlink()
            raise
        print(f'Applied and verified. Rollback saved at {STATE}')
    else:
        if not STATE.exists():
            print('No saved workspace changes to restore.')
            return
        items = json.loads(STATE.read_text())
        for item in items:
            current = read(item['channel'], item['property'])
            if current not in (item['old'], item['new']):
                raise RuntimeError(f"Later change to {item['property']}; restore cancelled.")
        for item in reversed(items):
            write(item, item['old'])
        STATE.unlink()
        print('Original workspace settings restored and verified.')


if __name__ == '__main__':
    main()
