# Convert an installed KDE system to MyLastArch

This toolkit applies the reusable parts of the MyLastArch ISO profile to an
existing **Arch Linux or Arch-based KDE Plasma installation**. It installs the
desktop packages, Cairo-Dock and its saved theme, Plasma defaults, wallpaper,
Dolphin actions, and hardware/printing services. The existing bootloader is
preserved by default.

The converter adds `/etc/mylastarch-release` as an identity marker, but keeps
Arch's package-managed `/etc/os-release` intact so system upgrades remain safe.

Live-image-only settings are deliberately excluded: Calamares, live-user
autologin, passwordless global Polkit, volatile journals, ISO networking, and
live-media services are never copied.

## Preview and install

Run this from the root of a complete `mylastarch-1.0` checkout:

```bash
sudo ./tools/convert-to-mylastarch/convert-to-mylastarch.sh --user YOUR_NAME
```

The normal command displays a numbered menu:

```text
1) Preview conversion; keep the current display manager
2) Install MyLastArch; keep the current display manager
3) Preview conversion; migrate SDDM to Plasma Login Manager
4) Install MyLastArch; migrate SDDM to Plasma Login Manager
5) Install desktop essentials only; keep the display manager
Q) Quit without making changes
```

Choice 1 is the default and is the recommended first run. Command-line options
remain available for unattended runs and automation.

Useful variants:

```bash
# Desktop essentials only
sudo ./tools/convert-to-mylastarch/convert-to-mylastarch.sh --user YOUR_NAME --no-apps

# Explicitly opt in to MyLastArch GRUB behavior and update hooks
sudo ./tools/convert-to-mylastarch/convert-to-mylastarch.sh --user YOUR_NAME --configure-grub

# Use only repositories already configured on the computer
sudo ./tools/convert-to-mylastarch/convert-to-mylastarch.sh --user YOUR_NAME --no-repo

# Keep the MyLastArch repository enabled after conversion
sudo ./tools/convert-to-mylastarch/convert-to-mylastarch.sh --user YOUR_NAME --repo-mode keep

# Do not install or use Yay for optional AUR packages
sudo ./tools/convert-to-mylastarch/convert-to-mylastarch.sh --user YOUR_NAME --no-yay

# Explicitly migrate an existing SDDM setup to Plasma Login Manager
sudo ./tools/convert-to-mylastarch/convert-to-mylastarch.sh --user YOUR_NAME --use-plasma-login
```

Files that are replaced are copied to a timestamped directory under
`/var/backups/mylastarch-converter/`. The script is idempotent and may be run
again after this repository is updated. Packages unavailable from the enabled
repositories are reported and skipped instead of aborting the whole conversion.
Existing JACK, PulseAudio, or PipeWire Media Session providers are preserved
instead of being removed automatically during the non-interactive conversion.
An existing display manager is also preserved; Plasma Login Manager and SDDM
are not replaced with one another when a working `display-manager.service`
alias is already configured.

The converter does not install the MyLastArch Viper GRUB theme and does not
modify the bootloader during normal interactive conversions. Advanced users
may pass `--configure-grub` to apply the reusable MyLastArch GRUB settings and
kernel-update hooks when GRUB is already installed. Other bootloaders remain
untouched.

When Plasma Login Manager is active, the converter installs the MyLastArch
login background and wallpaper-sync service. The branded wallpaper is the
fallback; when Variety has selected a valid user wallpaper, the login manager
uses that image on the next boot. Other display managers are left untouched.

Display-manager migration is deliberately opt-in. The interactive menu detects
the active manager and only offers migration when SDDM is present. The
`--use-plasma-login` automation option supports migration from SDDM, backs up
its configuration, preserves an existing SDDM autologin user/session in a
Plasma Login Manager drop-in, and records
`sddm.service` in `/var/lib/mylastarch-converter/previous-display-manager`, and
switches the `display-manager.service` alias without stopping the current
graphical session. SDDM remains installed for rollback. An unfamiliar active
display manager causes the requested migration to stop safely. Use
`--keep-display-manager` to state the default preservation policy explicitly.
To roll back after an SDDM migration, run
`sudo systemctl disable plasmalogin.service` followed by
`sudo systemctl enable --force sddm.service`, then reboot.
Converter versions that wrote the old two-line `/etc/plasmalogin.conf` are
detected by exact content, backed up, and replaced with the structured drop-in.
Any independently customized main configuration file is preserved.

When an existing user autostart entry launches Plank, it is backed up and
marked `Hidden=true` so Cairo-Dock is the only dock. The Plank package and its
configuration remain installed for easy restoration. Vivaldi uses automatic
Ozone platform selection so the same configuration works in both X11 and
Wayland Plasma sessions. The converter never distributes or replaces a full
Vivaldi profile. Interactive installations ask whether to preserve an existing
profile (the default) or merge only the MyLastArch new-tab and DuckDuckGo
defaults. Bookmarks, passwords, extensions, history, sessions, and other
preferences remain in place. Vivaldi must be closed for the optional merge; if
it is running, the merge is safely skipped with a warning.

The converter also supplies a Plasma-visible XScreenSaver Settings launcher,
because the upstream desktop file deliberately hides itself in KDE. If the
optional Arch Update package is unavailable, its copied tray autostart entry is
disabled instead of leaving a broken startup item.
The configured XScreenSaver image directory and its MyLastArch image are
installed under `/usr/share/backgrounds/mylastarch/xscreensaver-images/`, so
image-based savers do not fall back to color bars.

Dolphin is configured to use KDE 6's full-width status bar. The converter
merges only `General/ShowStatusBar=FullWidth` into an existing `dolphinrc`, so
other user preferences such as menu-bar visibility are preserved.

If LibreOffice Fresh is already installed, pacman's `--needed` behavior leaves
it unchanged. If LibreOffice Still, OnlyOffice, WPS Office, OpenOffice, or
Calligra is detected, the converter preserves the installed office suite and
skips LibreOffice Fresh. It does not replace an existing suite or install a
second suite alongside one of these recognized alternatives.

After rebooting, you may run the optional read-only validation check. It only
reports `[OK]` or `[FAIL]` and does not change the computer:

```bash
./tools/convert-to-mylastarch/validate-mylastarch.sh --user YOUR_NAME
```

Rebooting is recommended after conversion so the newly enabled services and
the complete Plasma/Cairo-Dock session start cleanly. For desktop-only changes,
logging out and back in is usually sufficient.

The package manifests are intentionally editable. Remove unwanted programs
from `packages-apps.txt`, or add distribution packages before running the
converter.

## Package sources

Interactive installations ask two independent questions. The first selects
whether the MyLastArch repository is used temporarily, kept enabled, or not
used. Temporary use is the recommended default: the converter installs its
prebuilt packages and then removes only the repository section it added from
`/etc/pacman.conf`. The trusted signing key remains installed.

The second question controls Yay for future AUR updates and repository
fallbacks. The converter always installs packages available through pacman
first, installs `yay-bin` from the MyLastArch repository when requested, and
runs Yay as the desktop user only when a listed package is unavailable through
pacman. Declining Yay does not prevent the core Plasma conversion; unavailable
community packages are listed instead.
The interactive screen displays this package list before asking, and the
installation log identifies whether each group is handled by pacman/MyLastArch
or Yay/AUR. Gittyup is intentionally excluded because it is a specialized,
time-consuming developer application rather than a general desktop component.
Pamac is also excluded because its all-features AUR dependency chain pulls in
Snap, Flatpak, Go, Vala, Meson, and numerous build-only components that are not
appropriate for a general KDE conversion.
Master PDF Editor is excluded because the available package redistributes an
old proprietary release with a custom license. Arch Linux Tweak Tool is also
excluded because it requires an additional third-party repository and is not a
core part of the MyLastArch desktop experience.
Each AUR package is installed in its own transaction, so a failed or cancelled
package is reported without preventing the rest of the conversion from
finishing. When `nss-mdns` is installed, the converter enables its NSS hosts
entry so `.local` NAS names advertised in Dolphin can resolve normally.
Warnings pause for a keypress during interactive terminal runs so they can be
read before installation continues. Redirected and unattended runs never pause.

The Strawberry configuration is included, but its generated catalog database
is not. Strawberry creates a fresh database on first launch, avoiding stale
catalog entries that can prevent tracks from playing. The converter pauses at
a first-use reminder: open Strawberry, select **Subsonic** at the bottom of the
left sidebar, and refresh the catalog before playing music. An existing user's
Strawberry database is not deleted or overwritten by the converter.
Before package installation, the converter records existing orphan packages.
After the AUR phase it removes only newly orphaned dependencies, cleaning up
temporary compilers, documentation generators, and other build-only tools
without touching packages or orphans that existed before conversion. Colored
phase headings, package lists, source messages, warnings, and errors make the
interactive output easier to scan; redirected logs remain plain text.

Packages whose names begin with `mylastarch-` do not receive updates while the
repository is disabled. The final summary identifies them and explains that
the repository must be re-enabled to update them. Packages that also exist in
the AUR can be updated by Yay after the temporary repository is removed.
