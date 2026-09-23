# MY LAST ARCH 2026.09.01

MY LAST ARCH is an Arch Linux-based live and installation image featuring the
KDE Plasma desktop. The project originated from the Carli-13 ISO profile and is
now maintained as an independent distribution.

## Release features

- KDE Plasma desktop
- Calamares graphical installer with MY LAST ARCH branding
- GRUB configured to remember the last selection and show a flat menu
- Intel and AMD microcode support
- Cairo-Dock with a curated launcher set
- Dolphin Actions submenu for common file-management tasks
- Gwenview image viewing and resizing

## Build requirements

The ISO must be built on Arch Linux with the required Archiso release:

```text
archiso 89-1
```

Install Archiso with Pacman. If the repository has moved to a newer release,
use the version documented in `archiso.readme` before building.

The build also uses packages from the MY LAST ARCH repository:

<https://github.com/mylastarch/mylastarch_repo/tree/main/x86_64>

The build script installs the MY LAST ARCH keyring when it is not already
present. It can also be installed separately with
`import-mylastarch-key.sh`.

## Building the ISO

Review the build script before running it. The first-build script clears the
Pacman package cache and uses `sudo` for Archiso operations.

Run:

```bash
./build-iso-scripts/30-build-the-iso-the-first-time.sh
```

For a subsequent local rebuild that retains the package cache, run:

```bash
./build-iso-scripts/40-build-the-iso-local-again.sh
```

The scripts copy the local `archiso` profile into `~/mylastarch-build` and
write the ISO, checksums, and package list to `~/mylastarch-Out`.

## Before publishing

Test installation and boot behavior in both BIOS and UEFI virtual machines.
Verify networking, audio, the Calamares installation flow, GRUB, installed
user defaults, and the generated checksums before publishing the image.

See `archiso.readme` for Archiso version-management notes.
