# Sanders backups, diagnosis and recovery

Status: revised design and command recipes, not deployed. Restic is available
in Termux's package collection but was **not installed** when inspected. No
backup, restore, service stop, package installation or watchdog rollout has run.
These recipes need a disposable-file trial with the installed Restic version
before use on the real setup. There is not yet an automated backup/report wrapper.

## Scope: Termux and its Ubuntu installation only

The goal is to fix individual problems using a known-good reference; full
rollback is the last resort. Save actual files, not just installation commands.

Observed setup: unrooted Android 12/API 31, native Termux, PRoot-Distro 4.37.0,
Ubuntu 25.10. Ubuntu is below Termux's `usr`; Tuvu lives in Termux home and is
bind-mounted into Ubuntu at `/srv/tuvu`. Use **native Termux** for reading files.
Scanning from Ubuntu can traverse PRoot's virtual `/proc` and storage mappings.

Included within the selected scope: SSH private/public/authorized keys and host
keys, shell startup files and saved command histories, scripts, aliases, service
launchers, boot scripts under `.termux`, desktop shortcuts, app settings, package
databases, installed executables/libraries, application data and source files.
Ubuntu scope includes `/root` as well as `/home/desktop` and system configuration.

Not included: Android app APKs/private Android preferences, phone shared storage,
external bind targets, remote databases, G14 files or G14 keys. Symlinks are saved
as links; targets outside scope are listed as dependencies, not followed. Existing
files already inside Termux remain included unless deliberately excluded.

This scope can repair Termux/Ubuntu files. It cannot recreate Android permissions,
Keystore credentials or authorized ADB after a factory reset. Record only the
small amount of version/access information needed to explain these dependencies;
do not export whole Android/G14 settings. Reauthentication may be needed.

## Use encrypted Restic snapshots, not a single gzip archive

A repository stores encrypted file versions and supports deduplication, selected
file recovery and inspection. A single `.tar.gz` is not the primary format because
its creation/extraction is not reliably resumable. Optional tar exports are for
interchange, not the resumable baseline. Do not use `termux-backup` alone: it
omits home. Installed PRoot-Distro's backup modifies permissions before archiving.

A snapshot is the agent's reference: repository location + exact snapshot ID +
scope + reports. The repository is useful on the phone or on a laptop with Restic;
it need not be extracted completely. Keep the repository password separately in a
password manager/offline safe place: losing it makes the backup unusable. Do not
store its only copy inside the source or encrypted repository. Never commit keys,
histories, reports or repository data to GitHub, even if encrypted.

## Backup profiles

| Profile | Included | Intended use / limitation |
| --- | --- | --- |
| `full` | Termux `home` and `usr`, including every installed PRoot rootfs | First baseline and last-resort whole-environment rollback |
| `termux` | Same two trees excluding `usr/var/lib/proot-distro/installed-rootfs` | Native tools, SSH/services, Tuvu and PRoot launcher/plugins; requires a separate Ubuntu snapshot |
| `ubuntu` | Complete Ubuntu rootfs plus Termux's PRoot plugin configuration | Guest-only baseline; does not contain Tuvu's host bind source or native VirGL/SSH |
| `config` | Explicit reviewed configuration/script/history allowlist plus reports | Frequent small diagnostic checkpoints, **not** complete disaster recovery |
| `custom` | Explicit paths within Termux `home`/`usr`, with a saved manifest | A selected app or project; dependencies must be listed |

The config allowlist should include Termux dotfiles, `.ssh`, `.termux`,
`.config`, `.local/bin`, relevant `.local/share` launchers, `usr/etc`,
`usr/var/service`; and Ubuntu `/etc`, root/desktop shell files, `.ssh`, `.config`,
`.local/bin`, application launchers, fonts/themes and package inventory. Review
app-specific locations; do not assert that every app's configuration is in
`.config`. Save the exact allowlist and missing/unreadable paths in the report.
Some app configs contain large profiles; show their size before selecting them.

Start with one `full` baseline if space permits. Then take `config` or `ubuntu`
checkpoints before related changes. Overlapping scopes in the same repository
can reuse stored content. A reduced profile must never be labeled a full backup.

### Avoid unnecessary bulk without losing the working setup

Exclude only runtime PID/socket/supervisor state by default. Do not exclude
`node_modules`, Python environments, installed extensions, model files, package
binaries or large files automatically: downloads/versions may not remain available.
An optional reviewed `lean` exclusion list may remove package-download caches,
browser caches and other regenerable caches. List exact paths and bytes saved.
Do not apply blanket `*.db`, `.local/share` or `.cache` exclusions. Never remove
files from the phone as part of backup. External symlink data stays out of scope.

## Execution location and destination are separate choices

| Start from | Destination | Route |
| --- | --- | --- |
| Native Termux | Phone | Restic local repository outside `home`/`usr`, e.g. shared storage containing encrypted repository files |
| Native Termux | G14 | Restic SFTP repository on G14; no full temporary archive needed on phone |
| G14 using ADB | Either | ADB forwards a connection to native Termux SSH; the reader still runs as the Termux UID |

Ordinary `adb shell` cannot read Termux private data on an unrooted phone. Do not
use `adb pull /data/data/com.termux` or promise an ADB-only backup if Termux SSH
is unavailable. Recover Termux first or use its Failsafe shell/bootstrap path.

From G14 PowerShell, with an authorized ADB connection:

```powershell
adb forward tcp:18022 tcp:8022
ssh -t -p 18022 u0_a468@127.0.0.1
```

Verify the server host key against the known Termux host key. Inside that **native
Termux** shell, run the same backup recipe as locally. Use an existing/native
`tmux` session so closing the client does not end a phone-local backup. ADB
forwarding itself is not durable; reestablish it after a disconnect.

A laptop destination needs an SSH/SFTP service on G14 (Windows OpenSSH or a
reachable WSL server), disk space, trusted host key and authenticated Termux access.
This is a prerequisite, not something currently configured by this guide.
Use a relative SFTP path to avoid guessing Windows drive syntax. For an existing
G14 SSH login named `backupuser`:

```bash
export RESTIC_REPOSITORY='sftp:backupuser@G14_ADDRESS:SandersBackups/restic'
```

Alternatively, if that server listens on G14 localhost port 22, PowerShell can
run `adb reverse tcp:18023 tcp:22`, and native Termux can use
`sftp://backupuser@127.0.0.1:18023/SandersBackups/restic`. Verify support and actual
server port first. The laptop must stay awake during transfers. Disconnection
interrupts the attempt; rerunning reuses saved data. Never disable SSH host checks.

For a phone destination instead:

```bash
export RESTIC_REPOSITORY='/sdcard/Download/SandersBackups/restic'
```

Encrypted repository files can live on shared/Windows storage; **restored Linux
files** must go to a private Linux filesystem to preserve modes and symlinks.
Test write/rename and interrupted-transfer behavior on the actual destination.
A phone-only copy does not survive phone storage loss. A second repository copy
can be kept off-device without backing up any G14 data.

## Planning: storage and time before the real backup

There is no honest exact compressed size or duration before scanning/processing.
Use two stages, and report uncertainty instead of an invented ETA:

1. Native Termux metadata scan: count files and apparent bytes per scope, largest
   directories/files, selected exclusions and unreadable paths. Show scan count
   and elapsed time; ETA can be unknown until the tree has been traversed.
2. Restic dry run against the selected initialized repository: show selected bytes,
   changes/new data estimate and counts. It can be I/O-heavy and requires repository
   credentials, but does not create a snapshot. It is not a zero-cost size query.

As a preliminary size check, native Termux can run `du -sk "$HOME" "$PREFIX"`
for allocated space, or `du -sb` for apparent bytes. These include the entire
selection before exclusions; use the exact profile/exclusions for the final plan.
Measure destination free space locally on G14 for SFTP (do not assume the phone
can query it). Disk figures from this session are stale and are not a capacity test.

For a first full backup, budget at least selected apparent bytes plus metadata
and a margin (e.g. 20%); this is a planning allowance, not a mathematical bound.
For later backups, show estimated additional data and retained repository size.
Restoring needs the uncompressed selection plus the old live files retained for
rollback. Check inodes/free space too. Never auto-prune to make a backup fit.

Before any measured run, show a range using stated assumed rates. Example:
10 GiB at 5–20 MiB/s is roughly 9–34 minutes for data movement alone, **plus**
scan, hashing, compression, many-small-file and verification costs. Calibrate with
a small representative trial on the actual phone/route; record rates, not secrets.
During execution display measured throughput, elapsed time, progress and updated
ETA. During restore, derive ETA from progress if the installed CLI does not show it.

The planned automation must present this information before starting. The recipes
below expose Restic's raw output; automatic scope scans/ETA tables are not yet built.

## Command recipe after tool installation and a fixture trial

Install Restic separately in native Termux only after reviewing that package
change (`pkg install restic`, not a blanket upgrade). Verify `restic version`,
`restic help backup` and `restic help restore` support these flags. Keep an
accessible copy/version record of the recovery tool. No installation has run yet.
Initialize a **new** chosen repository once with `restic init`, providing a unique
password interactively. Never initialize over an existing repository. Prompts or
a private password file outside the source are preferable to passwords in history.

In native Termux **bash**, choose a profile explicitly:

```bash
base=/data/data/com.termux/files
ubuntu_root="$base/usr/var/lib/proot-distro/installed-rootfs/ubuntu"
profile=full
sources=("$base/home" "$base/usr")
excludes=(
  --exclude "$base/usr/tmp/**"
  --exclude "$base/usr/var/run/**"
  --exclude "$base/usr/var/service/*/supervise"
  --exclude "$base/usr/var/service/*/log/supervise"
)
# For termux instead:
# profile=termux
# excludes+=(--exclude "$base/usr/var/lib/proot-distro/installed-rootfs")
# For ubuntu instead (keep the common runtime exclusions):
# profile=ubuntu
# sources=("$ubuntu_root" "$base/usr/etc/proot-distro")
```

Explicitly add guest runtime exclusions for each selected installed rootfs, such
as its `tmp/**` and `run/**`, after confirming they contain no required durable
files. The final plan must enumerate these exclusions. Never back up live virtual
mounts; this is why the reader runs outside PRoot. These examples use absolute
paths; keep that choice stable so restore paths and comparisons are predictable.

Store reports outside the source, e.g. `$base/backup-work/RUN_ID/reports`, and
append only that `reports` directory to `sources`. Keep progress logs outside it
during the run. Save the exact profile selection/exclusions for repeating a run.
`config`/`custom` require explicit reviewed source lists, not automatic guesses.

```bash
restic backup --dry-run --host sanders --tag "scope:$profile" \
  "${excludes[@]}" "${sources[@]}"
# After reviewing estimates and arranging consistency:
time restic backup --host sanders --tag "scope:$profile" \
  "${excludes[@]}" "${sources[@]}"
```

For live terminal progress, use a terminal/tmux rather than piping through `tee`.
For a future progress UI/report collector, use `--json` and consume JSON lines;
store stdout and stderr separately with the exit code. Backup status includes
elapsed/remaining time, files, bytes and errors. Restore has progress events too.
Progress is processed data, not necessarily bytes sent over the network.

## Consistency, interruption and retry

A Restic snapshot is a completed backup record, **not** an atomic filesystem
snapshot of a running phone. Save editor work and close Chromium/VS Code before
a baseline. Stop app/database writers gracefully in an agreed maintenance window;
record service state first. Use logical database dumps where applicable. Do not
copy a changing SQLite/WAL or PostgreSQL directory and call it consistent.
Remote data stays outside this backup's scope and is a documented dependency.

Keep SSH running if it is carrying backup traffic; do not blindly stop all runit
services as in a phone-only cold backup. Stop Tuvu/GUI/database writers individually
using their supported stop paths. If transport/logs change during a backup,
inspect errors and explicitly document any volatile-log exclusions. A service
`down` file is not proof no manual instance is running. Never force-kill everything.

Retry backup by rerunning the same command, profile, report set and destination.
It rescans and reuses indexed uploaded content; the last in-flight work may repeat.
No completed snapshot exists until the run finishes. If writers resumed after an
interruption, quiesce again: the retry captures the later state, not the original
interruption instant. Never bypass a lock while a writer may be alive. Remove a
stale lock only after checking for active clients. Do not prune between retries.

Treat nonzero exit codes as failures needing review. Restic can save a snapshot
with unreadable/missing source files (exit 3); such a snapshot is not the accepted
baseline. Save final snapshot ID, completion time, actual stored bytes and errors.
Restart exactly the services stopped, including after a failed attempt.

## Reports bundled with each snapshot

Keep these small, generated into the report directory before copying data:

- `README`: snapshot purpose, profile, consistency level, source-to-guest path map,
  exclusions and external dependencies. Snapshot ID is added to a separate run
  receipt after completion; a snapshot cannot contain its own final receipt.
- `inventory`: native/guest OS and architecture, Termux/PRoot/Restic versions,
  installed package names/versions from both dpkg databases, tool locations.
- `services`: launcher paths, runtime status, enabled/down state, listening ports,
  known start/stop commands; avoid process command lines containing credentials.
- `config-index`: selected file paths, sizes, modes, symlink targets and SHA-256
  of important configs/scripts for quick comparisons, with unreadable paths.
- `changes`: human change notes, repo status/commit identifiers and patch references
  where appropriate; never auto-publish diffs containing secrets.
- `restore-notes`: exact prerequisites, expected health checks, external bindings,
  and a reviewed optional post-restore checklist; no automatic execution.

Read guest package manifests directly or use short read-only PRoot commands
before quiescing. Do not start desktop apps just to obtain reports. Raw keys and
history are preserved in the data, not echoed in reports. Exclude huge logs from
reports while retaining selected original files according to the profile.

Saved `.bash_history`/`.zsh_history`, `.bashrc`, `.zshrc`, `.profile`, `.inputrc`,
Starship, XFCE settings, `.desktop` files and `.local/bin` scripts are included
where their parent scope is selected. Unsaved shell history needs a flush in each
interactive shell: Bash `history -a`, Zsh `fc -AI`; do this before the snapshot.
This cannot reconstruct commands never recorded by the shell.

## Diagnose first, restore selected files second

Give an agent this reference, keeping the password out of the prompt:

```text
Repository: <location>
Snapshot: <exact ID, not latest>
Scope: ubuntu
Symptom and change made: <description>
Read reports/config index, compare relevant saved files with current files,
propose the smallest repair. Do not overwrite live data or execute saved scripts.
```

Useful commands after unlocking the repository:

```bash
restic snapshots
restic ls SNAPSHOT_ID
restic diff BEFORE_ID AFTER_ID
restic dump SNAPSHOT_ID /data/data/com.termux/files/home/.bashrc
```

`diff` compares snapshot metadata/content identities, not a human-readable config
patch. For text, extract the selected old file into scratch space and run `diff -u`
against the live file. The Ubuntu path in the snapshot has the native rootfs
prefix, not simply `/home/desktop`. Reports and history can contain sensitive data;
inspect only relevant files, never execute commands found in history.

## Resumable restore with staging and verification

Use a fixed snapshot ID and a dedicated private **staging** destination. Never
restore directly over running `home`, `usr` or Ubuntu. Select exact paths from
`restic ls`; e.g. append `--include /data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu`
for a guest-only recovery from a full snapshot.

```bash
restic stats SNAPSHOT_ID --mode restore-size
restic restore SNAPSHOT_ID --target /data/data/com.termux/files/restore-stage-RUN_ID --dry-run
# After space/selection review:
time restic restore SNAPSHOT_ID --target /data/data/com.termux/files/restore-stage-RUN_ID --verify
```

If interrupted, rerun with the **same ID, selection and target**. Default restore
behavior checks existing content and writes needed data; partial work may repeat.
Do not use `--overwrite never` as a resume shortcut: it can retain partial files.
Do not use `--delete`. Keep staging dedicated to that restore; unrelated files
are not automatically removed. Use restore JSON progress for elapsed/processed
bytes and compute a rolling ETA if necessary; initial ETA may be unknown.

Absolute snapshot paths produce nested directories under staging. For this
recipe the staged home is `STAGE/data/data/com.termux/files/home`, not `STAGE/home`.
Inspect contents, links, modes and verification results before selecting it for
cutover. Record expected Android UID ownership; same-phone native restore is the
initial target. A new app UID requires explicit ownership review, not blindly
reapplying old UID values.

`restic check --read-data` verifies stored repository data; run it on the laptop
when possible to avoid phone load. Test full and partial restore, interrupted
backup/restore and text comparisons using disposable fixtures first. A real staged
extraction validates files, not ARM execution. A functional drill on a compatible
spare device is stronger; label an untested full cutover honestly.

## Cutover and post-restore actions

Only for a last-resort rollback, with saved work and verified ADB/scrcpy/Failsafe
access, stop affected writers and service supervision. Keep your maintenance
shell outside the affected directories. Move the old complete tree aside, then
put the verified staged tree at its original path. Keep the old tree until tests
pass. Pair `home`/`usr` from the same full snapshot when rolling back both. This
cutover is not atomic or resumable like data extraction; log each rename and
retain a concrete reverse-rename rollback plan. Do not delete the original to
make space or merge over live directories.

If Termux tools/SSH are already broken, Restic cannot magically run from the
broken prefix. Use Termux Failsafe through scrcpy to preserve the old trees and
establish a clean compatible Termux bootstrap/recovery tool first, or use a
separately tested rescue tool bundle. No standalone rescue binary has been
validated yet. Store repository credentials where they remain accessible. Losing
Android/ADB access can still require USB intervention; that is outside file backup.

Most shortcuts should return with restored files. After verification, optionally
run a reviewed, idempotent checklist in the correct native/guest environment:
refresh desktop-entry/icon/font caches only if needed; verify launcher executable
bits; recreate runtime directories; start only previously intended services; test
SSH, Ubuntu login, VNC, browser opening and application data. Do not replay shell
history, auto-enable Settings Sync, upgrade packages or execute arbitrary archived
scripts. Save hook output, duration and exit status; rerun only failed safe steps.
Post-restore automation is a separate explicit phase, not part of extraction.

## Acceptance before the next setup change

- Tools/version and selected destination tested on disposable files.
- Full or clearly scoped baseline completed with no unresolved source errors.
- Reports plus exact snapshot ID/run receipt saved; repository password recoverable.
- Repository check and staged sample restore passed, including interruption tests.
- Prior working snapshot retained and per-change rollback path specified.
- Watchdog and other live stability changes remain paused until baseline acceptance.

## Sources

- [Restic backup, dry runs and progress](https://restic.readthedocs.io/en/stable/040_backup.html)
- [Interrupted-backup semantics](https://restic.readthedocs.io/en/stable/faq.html)
- [Restore and existing-file handling](https://restic.readthedocs.io/en/stable/050_restore.html)
- [JSON progress and exit codes](https://restic.readthedocs.io/en/stable/075_scripting.html)
- [Local/SFTP repositories and passwords](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html)
- [Termux Restic package](https://github.com/termux/termux-packages/blob/master/packages/restic/build.sh)
- [Termux backup scope](https://raw.githubusercontent.com/termux/termux-tools/master/scripts/termux-backup.in)
- [PostgreSQL consistency requirements](https://www.postgresql.org/docs/current/backup-file.html)
- [ADB forwarding](https://developer.android.com/tools/adb#forwardports)

Installed PRoot-Distro 4.37.0 was inspected directly. Do not substitute the storage
layout/restore commands from a newer upstream version without checking them.
