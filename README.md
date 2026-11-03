# WowUp-CF for FreeBSD

A native FreeBSD build of [WowUp](https://wowup.io)'s CurseForge flavor (WowUp-CF), the World of Warcraft
addon manager. It runs on FreeBSD's own `electron42` package, with no Linux compatibility layer.

## How it works

WowUp is moving to a small native **shell** (Electron, a native addon and a bootstrap) that downloads and runs a
platform-independent, ed25519-signed **app bundle**. This repo builds only the shell, from upstream source plus
the patch in `patches/`. The app is WowUp's official `ow` bundle, which `build.sh` downloads from
[WowUp/wowup-bundles](https://github.com/WowUp/wowup-bundles) and the shell verifies (signature and file hashes)
on every launch. The shell also picks up new bundle releases on its own, like it does on other platforms.

The CurseForge API key belongs to WowUp and ships only inside their signed bundle. This repo does not contain
the bundle, the key, or anything taken from them.

The one FreeBSD-specific change: the bundle only supports Windows, macOS and Linux, and refuses to start
anywhere else. The shell tells the bundle it's running on `linux`. That matches FreeBSD for everything WowUp
does: unix paths, and WoW running under Wine.

## Requirements

```sh
pkg install electron42 node24 npm-node24 git
```

The C/C++ toolchain, `python3` and `gmake` are needed to build the native addon with node-gyp.

## Build and install

```sh
./build.sh                    # installs to ~/.local
PREFIX=/opt/wowup ./build.sh  # or elsewhere
```

This installs `$PREFIX/bin/wowup-cf`, the app in `$PREFIX/share/wowup-cf`, a `.desktop` entry (including the
`curseforge://` link handler) and an icon. Settings and logs go in `~/.config/WowUpCf`.

| Variable | Default | |
| --- | --- | --- |
| `PREFIX` | `~/.local` | install prefix |
| `CHANNEL` | `beta` | bundle channel; `stable` once WowUp publishes one for the shell |
| `WOWUP_REF` | pinned commit | upstream WowUp commit the shell is built from |
| `ELECTRON_DIR` | `/usr/local/share/electron42` | Electron to package |

## Adding your WoW install

WowUp only finds installs automatically through Lutris, so add yours by hand: **Options → WoW → Add**, then
pick the game executable inside the client folder, e.g. `World of Warcraft/_forever_/Wow.exe` for WoW: Forever,
or `_retail_/Wow.exe`, `_classic_era_/WowClassic.exe`.

## Known limitations

- The CurseForge flavor's ad is rendered by Overwolf's closed-source Electron fork, which doesn't exist for
  FreeBSD, so the ad space stays empty.
- WowUp's own app-update check (for new shell versions) only works for Linux AppImages and logs a harmless
  warning. Rebuild to update the shell; the app bundle updates by itself.
- The shell/bundle split hasn't shipped in a stable WowUp release yet, so this tracks WowUp's beta channel.

## License

GPL-3.0, same as WowUp. Not affiliated with WowUp, CurseForge or Overwolf.
