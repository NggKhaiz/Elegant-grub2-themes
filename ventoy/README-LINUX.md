# Raven Hub on Linux

## Install

1. Plug in the Ventoy USB; your desktop usually mounts it under
   `/media/$USER/<label>` (or `/run/media/$USER/<label>`).
2. Open a terminal in this folder and run:

   ```sh
   chmod +x install-ventoy.sh
   ./install-ventoy.sh --target /media/$USER/Ventoy
   ```

   Without `--target` the script lists mounted drives and asks.
3. Read the plan, answer `y`, reboot from the USB.

Useful variants:

```sh
./install-ventoy.sh --target "/media/$USER/My USB"   # paths with spaces work
./install-ventoy.sh --target /media/$USER/Ventoy --dry-run
./install-ventoy.sh --target /media/$USER/Ventoy --yes   # scripted use
```

The script uses plain POSIX shell, needs **no root**, and calls no
`mkfs`/`fdisk`/`parted`/`dd`/`Ventoy2Disk` — it only copies theme files and
edits `ventoy/ventoy.json`.

## "Target is not writable"

Some desktops mount USB drives for your user only after you open them once in
the file manager. If the script says the target is not writable:

* open the USB in your file manager once, then re-run; or
* mount it manually if you know how; or
* copy this folder's `ventoy` directory with your file manager (next section).

The script deliberately never runs sudo on its own.

## Manual installation

1. Copy this folder's `ventoy` directory to the root of the Ventoy USB data
   partition (the partition with your ISO files). In a terminal:

   ```sh
   cp -a ventoy /media/$USER/Ventoy/
   ```

2. If the USB has no `/media/$USER/Ventoy/ventoy/ventoy.json` yet:

   ```sh
   cd /media/$USER/Ventoy/ventoy
   cp ventoy.json.example ventoy.json
   ```

3. If `ventoy.json` already exists, do **not** overwrite it — replace only
   its `"theme"` object (see `README.md`), or use the installer which merges
   safely.
4. Reboot and pick the USB in your boot menu.

## Backup and rollback

The installer saves `ventoy.json.bak-YYYYMMDD-HHMMSS` before any change.

```sh
cp "/media/$USER/Ventoy/ventoy/ventoy.json.bak-20260821-130500" \
   "/media/$USER/Ventoy/ventoy/ventoy.json"
```

## Uninstall

```sh
./uninstall-ventoy.sh --target /media/$USER/Ventoy
```

That removes only `ventoy/theme/raven-hub` and the `"theme"` object in
`ventoy.json` (with another backup first). ISO files and other Ventoy
plugins are never touched. Details: `UNINSTALL.md`.
