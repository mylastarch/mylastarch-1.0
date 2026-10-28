#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
AIROOTFS="$PROJECT_ROOT/archiso/airootfs"
BACKUP_ROOT=/var/backups/mylastarch-converter
INSTALL_APPS=1
CONFIGURE_GRUB=0
REPO_MODE=temporary
INSTALL_YAY=1
DRY_RUN=0
REPO_PENDING=0
REPO_ADDED=0
SKIPPED_COMMUNITY=()
ORPHANS_BEFORE=()
BUILD_CLEANUP_DONE=0
USE_PLASMA_LOGIN=0
APPLY_VIVALDI_DEFAULTS=0
OPERATION_SELECTED=0
TARGET_USER=${SUDO_USER:-}

usage() {
    cat <<'EOF'
Usage: sudo ./tools/convert-to-mylastarch/convert-to-mylastarch.sh [options]

Turn an installed Arch Linux KDE Plasma system into MyLastArch.
With no operational options, an interactive menu is displayed.

Options:
  --user NAME       User whose desktop will be configured (default: SUDO_USER)
  --no-apps         Do not install the optional application collection
  --configure-grub  Opt in to MyLastArch GRUB settings and hooks
  --no-grub         Preserve the existing bootloader (default)
  --repo-mode MODE  MyLastArch repository policy: temporary, keep, or none
  --no-repo         Alias for --repo-mode none
  --install-yay     Install/use yay-bin for optional AUR packages (default)
  --no-yay          Do not install optional AUR packages
  --use-plasma-login
                    Migrate SDDM to Plasma Login Manager on the next boot
  --keep-display-manager
                    Preserve the active display manager (default)
  --apply-vivaldi-defaults
                    Apply only the MyLastArch new-tab and search defaults
  --preserve-vivaldi
                    Preserve an existing Vivaldi profile (default)
  --dry-run         Print actions without changing the computer
  -h, --help        Show this help
EOF
}

if [[ -t 1 ]]; then
    BOLD='\033[1m'; GREEN='\033[1;32m'; CYAN='\033[1;36m'
    YELLOW='\033[1;33m'; RED='\033[1;31m'; RESET='\033[0m'
else
    BOLD=''; GREEN=''; CYAN=''; YELLOW=''; RED=''; RESET=''
fi
log() { printf '\n%b==> %s%b\n' "$CYAN" "$*" "$RESET"; }
pause_after_warning() {
    # Pausing a redirected or automated run would leave it stuck forever.
    # Interactive terminal runs pause so the warning cannot scroll past.
    [[ -t 0 && -t 1 ]] || return 0
    printf '%bPress any key to continue...%b' "$YELLOW" "$RESET" >&2
    IFS= read -r -n 1 -s _ || true
    printf '\n' >&2
}
warn() {
    printf '%bwarning: %s%b\n' "$YELLOW" "$*" "$RESET" >&2
    pause_after_warning
}
die() { printf '%berror: %s%b\n' "$RED" "$*" "$RESET" >&2; exit 1; }
PHASE_NUMBER=0
phase() {
    local title=$1
    shift
    PHASE_NUMBER=$((PHASE_NUMBER + 1))
    printf '\n%b' "$GREEN"
    printf '%s\n' '##################################################################'
    printf 'Phase %d: %s\n' "$PHASE_NUMBER" "$title"
    local detail
    for detail in "$@"; do printf '%s\n' "- $detail"; done
    printf '%s' '##################################################################'
    printf '%b\n\n' "$RESET"
}
run() {
    if (( DRY_RUN )); then printf '  + '; printf '%q ' "$@"; printf '\n';
    else "$@"; fi
}

while (($#)); do
    case $1 in
        --user) (($# >= 2)) || die "--user needs a value"; TARGET_USER=$2; shift 2 ;;
        --no-apps) INSTALL_APPS=0; OPERATION_SELECTED=1; shift ;;
        --configure-grub) CONFIGURE_GRUB=1; OPERATION_SELECTED=1; shift ;;
        --no-grub) CONFIGURE_GRUB=0; OPERATION_SELECTED=1; shift ;;
        --repo-mode)
            (($# >= 2)) || die "--repo-mode needs temporary, keep, or none"
            case $2 in temporary|keep|none) REPO_MODE=$2 ;; *) die "invalid repository mode: $2" ;; esac
            OPERATION_SELECTED=1; shift 2 ;;
        --no-repo) REPO_MODE=none; OPERATION_SELECTED=1; shift ;;
        --install-yay) INSTALL_YAY=1; OPERATION_SELECTED=1; shift ;;
        --no-yay) INSTALL_YAY=0; OPERATION_SELECTED=1; shift ;;
        --use-plasma-login) USE_PLASMA_LOGIN=1; OPERATION_SELECTED=1; shift ;;
        --keep-display-manager) USE_PLASMA_LOGIN=0; OPERATION_SELECTED=1; shift ;;
        --apply-vivaldi-defaults) APPLY_VIVALDI_DEFAULTS=1; OPERATION_SELECTED=1; shift ;;
        --preserve-vivaldi) APPLY_VIVALDI_DEFAULTS=0; OPERATION_SELECTED=1; shift ;;
        --dry-run) DRY_RUN=1; OPERATION_SELECTED=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done

show_main_menu() {
    local choice display_manager resolved current_unit
    [[ -t 0 ]] || die "interactive menu needs a terminal; use --dry-run or another option for unattended use"
    if [[ -z $TARGET_USER || $TARGET_USER == root ]]; then
        read -r -p 'Enter the existing desktop username: ' TARGET_USER
    fi
    display_manager=/etc/systemd/system/display-manager.service
    resolved=""
    if [[ -e $display_manager || -L $display_manager ]]; then
        resolved=$(readlink -f "$display_manager")
    fi
    current_unit=${resolved##*/}
    printf '\n'
    printf '%s\n' '##################################################################'
    printf '%s\n' '                 MYLASTARCH CONVERTER MENU'
    printf '%s\n' '##################################################################'
    printf '  Existing desktop user : %s (the converter never creates users)\n' "$TARGET_USER"
    printf '  Detected display manager: %s\n' "${current_unit:-none}"
    printf '%s\n' '##################################################################'
    if [[ $current_unit == sddm.service ]]; then
        printf '%s\n' '  1) Preview conversion; keep SDDM'
        printf '%s\n' '  2) Install MyLastArch; keep SDDM'
        printf '%s\n' '  3) Preview conversion; migrate SDDM to Plasma Login Manager'
        printf '%s\n' '  4) Install MyLastArch; migrate SDDM to Plasma Login Manager'
        printf '%s\n' '  5) Install desktop essentials only; keep SDDM'
    else
        printf '%s\n' '  1) Preview conversion; preserve the detected display manager'
        printf '%s\n' '  2) Install MyLastArch; preserve the detected display manager'
        printf '%s\n' '  3) Install desktop essentials only; preserve the display manager'
    fi
    printf '%s\n' '  Q) Quit without making changes'
    printf '%s\n' '##################################################################'
    read -r -p 'Enter a choice [1]: ' choice
    choice=${choice:-1}
    if [[ $current_unit == sddm.service ]]; then
        case ${choice,,} in
            1) DRY_RUN=1; USE_PLASMA_LOGIN=0 ;;
            2) DRY_RUN=0; USE_PLASMA_LOGIN=0 ;;
            3) DRY_RUN=1; USE_PLASMA_LOGIN=1 ;;
            4) DRY_RUN=0; USE_PLASMA_LOGIN=1 ;;
            5) DRY_RUN=0; USE_PLASMA_LOGIN=0; INSTALL_APPS=0 ;;
            q) printf 'Conversion cancelled. No changes were made.\n'; exit 0 ;;
            *) die "invalid menu choice: $choice" ;;
        esac
    else
        case ${choice,,} in
            1) DRY_RUN=1; USE_PLASMA_LOGIN=0 ;;
            2) DRY_RUN=0; USE_PLASMA_LOGIN=0 ;;
            3) DRY_RUN=0; USE_PLASMA_LOGIN=0; INSTALL_APPS=0 ;;
            q) printf 'Conversion cancelled. No changes were made.\n'; exit 0 ;;
            *) die "invalid menu choice: $choice" ;;
        esac
    fi
}

choose_package_sources() {
    local choice package
    [[ -t 0 ]] || return 0
    printf '\n%s\n' '##################################################################'
    printf '%s\n' '              PACKAGE SOURCE AND UPDATE CHOICES'
    printf '%s\n' '##################################################################'
    printf '%b%s%b\n' "$BOLD" 'Optional packages checked in MyLastArch first, then the AUR:' "$RESET"
    while IFS= read -r package; do
        package=${package%%#*}; package=${package//[[:space:]]/}
        [[ -n $package ]] && printf '%b  - %s%b\n' "$CYAN" "$package" "$RESET"
    done < "$SCRIPT_DIR/packages-aur.txt"
    printf '%b%s%b\n' "$CYAN" '  - yay-bin (installed when Yay is requested and not already present)' "$RESET"
    printf '%b%s%b\n' "$YELLOW" 'You may uninstall any of these packages after conversion.' "$RESET"
    printf '%s\n' '##################################################################'
    printf '%s\n' 'MyLastArch repository policy:'
    printf '%s\n' '  1) Use during conversion, then remove it (recommended)'
    printf '%s\n' '  2) Enable it and keep it for MyLastArch-specific updates'
    printf '%s\n' '  3) Do not enable it; unavailable packages will be skipped'
    read -r -p 'Enter a choice [1]: ' choice
    case ${choice:-1} in
        1) REPO_MODE=temporary ;;
        2) REPO_MODE=keep ;;
        3) REPO_MODE=none ;;
        *) die "invalid repository choice: $choice" ;;
    esac

    printf '\n%s\n' 'Optional AUR support and future updates:'
    printf '%s\n' '  1) Install/use yay-bin for AUR updates and repository fallbacks (recommended)'
    printf '%s\n' '  2) Do not use Yay; unavailable community packages will be listed and skipped'
    read -r -p 'Enter a choice [1]: ' choice
    case ${choice:-1} in
        1) INSTALL_YAY=1 ;;
        2) INSTALL_YAY=0 ;;
        *) die "invalid AUR choice: $choice" ;;
    esac

    (( INSTALL_APPS )) || return 0
    printf '\n%s\n' 'Vivaldi preferences:'
    printf '%s\n' '  1) Preserve an existing Vivaldi profile (recommended)'
    printf '%s\n' '     MyLastArch defaults are used only when no profile exists.'
    printf '%s\n' '  2) Apply the MyLastArch new-tab and DuckDuckGo defaults'
    printf '%s\n' '     Bookmarks, passwords, extensions, history, and tabs are preserved.'
    read -r -p 'Enter a choice [1]: ' choice
    case ${choice:-1} in
        1) APPLY_VIVALDI_DEFAULTS=0 ;;
        2) APPLY_VIVALDI_DEFAULTS=1 ;;
        *) die "invalid Vivaldi preference choice: $choice" ;;
    esac
}

if (( ! OPERATION_SELECTED )); then
    show_main_menu
    choose_package_sources
fi

phase "Preflight checks" \
    "Confirming this is an Arch-based system" \
    "Checking the target user and converter payload"
[[ $EUID -eq 0 ]] || die "run this script with sudo"
[[ -r /etc/arch-release ]] || die "only Arch Linux and Arch-based installations are supported"
command -v pacman >/dev/null || die "pacman was not found"
[[ -d $AIROOTFS ]] || die "run this script from a complete mylastarch-1.0 checkout"
[[ -n $TARGET_USER && $TARGET_USER != root ]] || die "cannot determine the desktop user; pass --user NAME"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[[ -n $TARGET_HOME && -d $TARGET_HOME ]] || die "home directory for '$TARGET_USER' was not found"
mapfile -t ORPHANS_BEFORE < <(pacman -Qdtq 2>/dev/null || true)

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$BACKUP_ROOT/$STAMP"
if (( ! DRY_RUN )); then install -d -m 700 "$BACKUP"; fi

backup_path() {
    local path=$1 relative=${1#/}
    [[ -e $path || -L $path ]] || return 0
    run install -d -m 700 "$BACKUP/$(dirname "$relative")"
    run cp -a -- "$path" "$BACKUP/$relative"
}

install_available_packages() {
    local manifest=$1
    local label=$2
    local package
    local office_suite
    local available=()
    local missing=()
    local deferred=()
    local preserved=()
    local installed_office_suites=()

    # An existing system may already use LibreOffice Still or a different
    # office suite. Preserve that choice instead of creating a conflict or
    # installing a second suite merely because Fresh is in the app manifest.
    for office_suite in \
        libreoffice-still \
        onlyoffice-bin \
        onlyoffice-desktopeditors \
        wps-office \
        openoffice-bin \
        calligra; do
        if pacman -Q -- "$office_suite" >/dev/null 2>&1; then
            installed_office_suites+=("$office_suite")
        fi
    done

    while IFS= read -r package; do
        package=${package%%#*}; package=${package//[[:space:]]/}
        [[ -n $package ]] || continue

        # Preserve a working audio provider rather than allowing pacman to
        # remove it implicitly during a non-interactive conversion.
        case $package in
            libreoffice-fresh)
                if ((${#installed_office_suites[@]})); then
                    preserved+=("libreoffice-fresh (keeping ${installed_office_suites[*]})")
                    continue
                fi
                ;;
            pipewire-jack)
                if pacman -Q jack2 >/dev/null 2>&1; then
                    preserved+=("pipewire-jack (keeping jack2)")
                    continue
                fi
                ;;
            pipewire-pulse)
                if pacman -Q pulseaudio >/dev/null 2>&1; then
                    preserved+=("pipewire-pulse (keeping pulseaudio)")
                    continue
                fi
                ;;
            pipewire-alsa)
                if pacman -Q pulseaudio-alsa >/dev/null 2>&1; then
                    preserved+=("pipewire-alsa (keeping pulseaudio-alsa)")
                    continue
                fi
                ;;
            wireplumber)
                if pacman -Q pipewire-media-session >/dev/null 2>&1; then
                    preserved+=("wireplumber (keeping pipewire-media-session)")
                    continue
                fi
                ;;
        esac

        if pacman -Si -- "$package" >/dev/null 2>&1; then
            available+=("$package")
        elif (( DRY_RUN && REPO_PENDING )); then
            # The dry run deliberately does not add or sync the repository, so
            # packages supplied by it cannot be queried until the real run.
            available+=("$package")
            deferred+=("$package")
        else
            missing+=("$package")
        fi
    done < "$manifest"
    if ((${#available[@]})); then run pacman -S --needed --noconfirm "${available[@]}"; fi
    if ((${#preserved[@]})); then warn "$label packages skipped to preserve installed software/providers: ${preserved[*]}"; fi
    if ((${#deferred[@]})); then warn "$label package availability will be resolved after the MyLastArch repository is enabled: ${deferred[*]}"; fi
    if ((${#missing[@]})); then warn "$label packages not found in enabled repositories: ${missing[*]}"; fi
    return 0
}

configure_repo() {
    [[ $REPO_MODE != none ]] || {
        log "Continuing without the MyLastArch repository"
        return 0
    }
    if ! grep -q '^\[mylastarch_repo\]' /etc/pacman.conf; then
        log "Trusting and enabling the MyLastArch repository"
        run pacman-key --recv-keys C8B25E49B0428123 --keyserver keyserver.ubuntu.com
        run pacman-key --lsign-key C8B25E49B0428123
        backup_path /etc/pacman.conf
        if (( DRY_RUN )); then
            REPO_PENDING=1
            REPO_ADDED=1
            printf '  + append [mylastarch_repo] to /etc/pacman.conf\n'
        else
            sed -i '/^\[core\]/i [mylastarch_repo]\nSigLevel = Required DatabaseOptional\nServer = https://mylastarch.github.io/$repo/$arch\n' /etc/pacman.conf
            REPO_ADDED=1
        fi
    elif [[ $REPO_MODE == temporary ]]; then
        backup_path /etc/pacman.conf
        REPO_ADDED=1
        log "Using the existing MyLastArch repository temporarily; it will be removed when finished"
    fi
    run pacman -Sy
}

remove_temporary_repo() {
    [[ $REPO_MODE == temporary ]] || return 0
    if (( ! REPO_ADDED )); then
        log "The MyLastArch repository was already configured; leaving it unchanged"
        return 0
    fi
    log "Removing the temporary MyLastArch repository from pacman.conf"
    if (( DRY_RUN )); then
        printf '  + remove the [mylastarch_repo] section added during this run\n'
        REPO_ADDED=0
        return 0
    fi
    sed -i '/^\[mylastarch_repo\]$/,/^$/d' /etc/pacman.conf
    REPO_ADDED=0
}

install_community_packages() {
    local package
    local repo_packages=()
    local aur_packages=()
    local skipped=()
    while IFS= read -r package; do
        package=${package%%#*}; package=${package//[[:space:]]/}
        [[ -n $package ]] || continue
        if pacman -Si -- "$package" >/dev/null 2>&1 || (( DRY_RUN && REPO_PENDING )); then
            repo_packages+=("$package")
        elif (( INSTALL_YAY )); then
            aur_packages+=("$package")
        else
            skipped+=("$package")
        fi
    done < "$SCRIPT_DIR/packages-aur.txt"

    if ((${#repo_packages[@]})); then
        log "Installing optional packages through pacman/MyLastArch: ${repo_packages[*]}"
        run pacman -S --needed --noconfirm "${repo_packages[@]}"
    fi
    if ((${#aur_packages[@]})); then
        if ! command -v yay >/dev/null 2>&1; then
            if [[ $REPO_MODE != none ]]; then
                run pacman -S --needed --noconfirm yay-bin
            fi
        fi
        if (( DRY_RUN )) || command -v yay >/dev/null 2>&1; then
            log "Installing optional AUR packages individually as $TARGET_USER"
            for package in "${aur_packages[@]}"; do
                printf '  AUR package: %s\n' "$package"
                if ! run runuser -u "$TARGET_USER" -- yay -S --needed --noconfirm "$package"; then
                    skipped+=("$package")
                    warn "AUR installation failed and conversion will continue: $package"
                fi
            done
        else
            skipped+=("${aur_packages[@]}")
            warn "yay is unavailable; optional AUR packages were skipped"
        fi
    fi
    if ((${#skipped[@]})); then
        SKIPPED_COMMUNITY+=("${skipped[@]}")
        warn "optional community packages not installed: ${skipped[*]}"
        printf '  These applications can be installed later after enabling the MyLastArch\n'
        printf '  repository or installing an AUR helper: %s\n' "${skipped[*]}"
    fi
}

cleanup_new_build_dependencies() {
    (( BUILD_CLEANUP_DONE )) && return 0
    local package before_package existing
    local after=()
    local newly_orphaned=()
    mapfile -t after < <(pacman -Qdtq 2>/dev/null || true)
    for package in "${after[@]}"; do
        existing=0
        for before_package in "${ORPHANS_BEFORE[@]}"; do
            if [[ $package == "$before_package" ]]; then existing=1; break; fi
        done
        (( existing )) || newly_orphaned+=("$package")
    done
    if ((${#newly_orphaned[@]})); then
        log "Removing temporary build dependencies: ${newly_orphaned[*]}"
        if ! run pacman -Rns --noconfirm -- "${newly_orphaned[@]}"; then
            warn "automatic build-dependency cleanup failed; the packages remain installed"
        fi
    else
        log "No temporary orphaned build dependencies need removal"
    fi
    BUILD_CLEANUP_DONE=1
}

configure_mdns_resolution() {
    pacman -Q nss-mdns >/dev/null 2>&1 || return 0
    grep -Eq '^hosts:.*mdns' /etc/nsswitch.conf && return 0
    backup_path /etc/nsswitch.conf
    log "Enabling .local hostname resolution for Dolphin network discovery"
    if (( DRY_RUN )); then
        printf '  + add mdns_minimal [NOTFOUND=return] to the hosts line in /etc/nsswitch.conf\n'
    else
        sed -i -E '/^hosts:/ s/[[:space:]]+resolve/ mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf
        if ! grep -Eq '^hosts:.*mdns' /etc/nsswitch.conf; then
            sed -i -E '/^hosts:/ s/$/ mdns_minimal [NOTFOUND=return]/' /etc/nsswitch.conf
        fi
    fi
}

show_package_source_summary() {
    local package
    local mylastarch_only=()
    printf '\nPACKAGE SOURCES AND FUTURE UPDATES:\n'
    case $REPO_MODE in
        temporary) printf '  MyLastArch repository: removed after installation\n' ;;
        keep) printf '  MyLastArch repository: kept enabled for future updates\n' ;;
        none) printf '  MyLastArch repository: not enabled\n' ;;
    esac
    if command -v yay >/dev/null 2>&1; then
        printf '  AUR support: yay is installed; matching foreign packages can be updated\n'
    else
        printf '  AUR support: unavailable; optional AUR packages require manual installation\n'
    fi
    if [[ $REPO_MODE != keep ]]; then
        while IFS= read -r package; do
            [[ $package == mylastarch-* ]] && mylastarch_only+=("$package")
        done < <(pacman -Qq 2>/dev/null || true)
        if ((${#mylastarch_only[@]})); then
            printf '  MyLastArch-only packages need the repository re-enabled to update:\n'
            printf '    %s\n' "${mylastarch_only[*]}"
        fi
    fi
    if ((${#SKIPPED_COMMUNITY[@]})); then
        printf '  Optional community packages skipped:\n'
        printf '    %s\n' "${SKIPPED_COMMUNITY[*]}"
    fi
}

copy_system_file() {
    local relative=$1
    local mode=${2:-644}
    local source="$AIROOTFS/$relative"
    local destination="/$relative"
    [[ -f $source ]] || die "payload is missing $relative"
    backup_path "$destination"
    run install -D -m "$mode" "$source" "$destination"
}

enable_if_available() {
    local unit=$1
    if (( DRY_RUN )); then run systemctl enable "$unit"
    elif systemctl cat "$unit" >/dev/null 2>&1; then run systemctl enable "$unit";
    else warn "systemd unit is unavailable and was not enabled: $unit"; fi
}

read_sddm_autologin_value() {
    local wanted=$1 file
    local files=()
    for file in /usr/lib/sddm/sddm.conf.d/*.conf /etc/sddm.conf.d/*.conf /etc/sddm.conf; do
        [[ -f $file ]] && files+=("$file")
    done
    ((${#files[@]})) || return 0
    awk -F= -v wanted="$wanted" '
        /^[[:space:]]*\[/ {
            section=$0
            gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", section)
            next
        }
        section == "Autologin" {
            key=$1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            if (key == wanted) {
                value=substr($0, index($0, "=") + 1)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                found=value
            }
        }
        END { if (found != "") print found }
    ' "${files[@]}"
}

migrate_sddm_autologin() {
    local user session relogin destination
    user=$(read_sddm_autologin_value User)
    session=$(read_sddm_autologin_value Session)
    relogin=$(read_sddm_autologin_value Relogin)
    [[ -n $user ]] || return 0
    getent passwd "$user" >/dev/null || die "SDDM autologin references unknown user: $user"

    session=${session:-plasma}
    if [[ $session != *.desktop ]]; then session="${session}.desktop"; fi
    relogin=${relogin:-false}
    destination=/etc/plasmalogin.conf.d/20-mylastarch-autologin.conf
    backup_path "$destination"
    if (( DRY_RUN )); then
        printf '  + preserve autologin for user %s with session %s\n' "$user" "$session"
    else
        install -d -m 0755 /etc/plasmalogin.conf.d
        {
            printf '%s\n' '[Autologin]'
            printf 'User=%s\n' "$user"
            printf 'Session=%s\n' "$session"
            printf 'Relogin=%s\n' "$relogin"
        } > "$destination"
        chmod 0644 "$destination"
    fi
    log "Preserved SDDM autologin for $user ($session)"
}

recover_sddm_autologin_if_needed() {
    local file
    for file in /etc/plasmalogin.conf /etc/plasmalogin.conf.d/*.conf; do
        [[ -f $file ]] || continue
        if awk '
            /^[[:space:]]*\[/ {
                section=$0
                gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", section)
                next
            }
            section == "Autologin" && /^[[:space:]]*User[[:space:]]*=/ { found=1 }
            END { exit !found }
        ' "$file"; then
            log "Keeping the existing Plasma Login Manager autologin configuration"
            return 0
        fi
    done
    migrate_sddm_autologin
}

remove_legacy_plm_wallpaper_config() {
    local legacy=/etc/plasmalogin.conf
    [[ -f $legacy ]] || return 0
    if cmp -s "$legacy" "$AIROOTFS/etc/plasmalogin.conf"; then
        log "Replacing the converter's legacy Plasma Login Manager configuration"
        backup_path "$legacy"
        run rm -f -- "$legacy"
    fi
}

enable_display_manager() {
    local display_manager=/etc/systemd/system/display-manager.service
    local resolved=""
    local current_unit=""
    if [[ -e $display_manager || -L $display_manager ]]; then
        resolved=$(readlink -f "$display_manager")
        current_unit=${resolved##*/}
        if [[ $current_unit == plasmalogin.service ]]; then
            log "Plasma Login Manager is already the active display manager"
            return 0
        fi
        if (( ! USE_PLASMA_LOGIN )); then
            log "Keeping the existing display manager: $resolved"
            return 0
        fi
        if [[ $current_unit != sddm.service ]]; then
            die "automatic display-manager migration supports SDDM only; found $current_unit"
        fi
        if (( ! DRY_RUN )) && ! systemctl cat plasmalogin.service >/dev/null 2>&1; then
            die "Plasma Login Manager is not installed; SDDM was left unchanged"
        fi

        log "Migrating SDDM to Plasma Login Manager for the next boot"
        backup_path "$display_manager"
        backup_path /etc/sddm.conf
        backup_path /etc/sddm.conf.d
        backup_path /etc/pam.d/sddm
        backup_path /etc/pam.d/sddm-autologin
        migrate_sddm_autologin
        if (( DRY_RUN )); then
            printf '  + record sddm.service as the previous display manager\n'
        else
            install -d -m 0755 /var/lib/mylastarch-converter
            printf '%s\n' sddm.service > /var/lib/mylastarch-converter/previous-display-manager
        fi
        run systemctl disable sddm.service
        run systemctl enable --force plasmalogin.service
        if (( ! DRY_RUN )); then
            resolved=$(readlink -f "$display_manager")
            [[ ${resolved##*/} == plasmalogin.service ]] || \
                die "Plasma Login Manager was installed but did not become display-manager.service"
        fi
        log "SDDM remains installed for rollback; the current session was not stopped"
        return 0
    fi

    if (( USE_PLASMA_LOGIN )); then
        log "No active display manager was found; selecting Plasma Login Manager"
    fi
    if systemctl cat plasmalogin.service >/dev/null 2>&1; then
        run systemctl enable plasmalogin.service
    elif systemctl cat sddm.service >/dev/null 2>&1; then
        run systemctl enable sddm.service
    else
        warn "no supported display manager unit is available"
    fi
    return 0
}

configure_plasma_login_manager() {
    local display_manager=/etc/systemd/system/display-manager.service
    local resolved=""
    if [[ -e $display_manager || -L $display_manager ]]; then
        resolved=$(readlink -f "$display_manager")
    fi
    if (( DRY_RUN && USE_PLASMA_LOGIN )) && [[ ${resolved##*/} == sddm.service ]]; then
        # The dry run prints the migration commands without changing the
        # display-manager symlink, so preview the resulting PLM setup here.
        resolved=/usr/lib/systemd/system/plasmalogin.service
    fi
    if [[ ${resolved##*/} != plasmalogin.service ]]; then
        log "Plasma Login Manager is not active; its wallpaper setup was skipped"
        return 0
    fi

    log "Installing the MyLastArch Plasma Login Manager background"
    if (( ! DRY_RUN )); then
        getent passwd plasmalogin >/dev/null || die "the plasmalogin service account is missing"
        getent group plasmalogin >/dev/null || die "the plasmalogin service group is missing"
    fi

    recover_sddm_autologin_if_needed
    remove_legacy_plm_wallpaper_config

    copy_system_file etc/plasmalogin.conf.d/10-mylastarch-wallpaper.conf 644
    copy_system_file usr/local/libexec/plm-wallpaper-sync 755
    copy_system_file etc/systemd/system/plm-wallpaper-sync.service 644
    copy_system_file etc/systemd/system/plasmalogin.service.d/mylastarch-wallpaper.conf 644

    backup_path /var/lib/plasmalogin/wallpapers/01.jpg
    backup_path /var/lib/plasmalogin/wallpapers/01-org.jpg
    run install -d -m 0750 -o plasmalogin -g plasmalogin \
        /var/lib/plasmalogin/wallpapers
    run install -m 0644 -o plasmalogin -g plasmalogin \
        "$AIROOTFS/var/lib/plasmalogin/wallpapers/01.jpg" \
        /var/lib/plasmalogin/wallpapers/01.jpg
    run install -m 0644 -o plasmalogin -g plasmalogin \
        "$AIROOTFS/var/lib/plasmalogin/wallpapers/01-org.jpg" \
        /var/lib/plasmalogin/wallpapers/01-org.jpg
    run systemctl daemon-reload
    run systemctl start plm-wallpaper-sync.service
}

PLASMA_WAS_RUNNING=0
user_systemctl() {
    run runuser -u "$TARGET_USER" -- env \
        "XDG_RUNTIME_DIR=/run/user/$(id -u "$TARGET_USER")" \
        systemctl --user "$@"
}

restart_plasma_if_needed() {
    if (( PLASMA_WAS_RUNNING )); then
        user_systemctl start plasma-plasmashell.service || true
        PLASMA_WAS_RUNNING=0
    fi
}

cleanup_on_exit() {
    restart_plasma_if_needed || true
    cleanup_new_build_dependencies || true
    if [[ $REPO_MODE == temporary ]] && (( REPO_ADDED )); then
        warn "conversion exited before repository cleanup; removing the temporary MyLastArch repository"
        if (( ! DRY_RUN )); then
            sed -i '/^\[mylastarch_repo\]$/,/^$/d' /etc/pacman.conf || true
        fi
        REPO_ADDED=0
    fi
}

stop_plasma_if_running() {
    local runtime_dir="/run/user/$(id -u "$TARGET_USER")"
    if [[ -d $runtime_dir ]] && runuser -u "$TARGET_USER" -- env \
        "XDG_RUNTIME_DIR=$runtime_dir" systemctl --user is-active --quiet \
        plasma-plasmashell.service; then
        log "Temporarily stopping Plasma so it cannot overwrite the new layout"
        PLASMA_WAS_RUNNING=1
        user_systemctl stop plasma-plasmashell.service
    fi
}

disable_competing_plank() {
    local autostart_dir="$TARGET_HOME/.config/autostart"
    local file found=0
    [[ -d $autostart_dir ]] || return 0
    while IFS= read -r -d '' file; do
        if grep -Eq '^[[:space:]]*Exec=([^[:space:]]*/)?plank([[:space:]]|$)' "$file"; then
            found=1
            backup_path "$file"
            if (( DRY_RUN )); then
                printf '  + disable competing Plank autostart: %s\n' "$file"
            else
                sed -i '/^[[:space:]]*Hidden=/d' "$file"
                printf '%s\n' 'Hidden=true' >> "$file"
                chown "$TARGET_USER:$(id -gn "$TARGET_USER")" "$file"
                chmod 0644 "$file"
            fi
        fi
    done < <(find "$autostart_dir" -maxdepth 1 -type f -name '*.desktop' -print0)
    if (( found )); then
        log "Disabled Plank autostart entries so Cairo-Dock is the only dock"
        run runuser -u "$TARGET_USER" -- pkill -x plank || true
    fi
}

disable_missing_arch_update_autostart() {
    local file="$TARGET_HOME/.config/autostart/arch-update-tray.desktop"
    command -v arch-update >/dev/null 2>&1 && return 0
    [[ -f $file ]] || return 0
    backup_path "$file"
    if (( DRY_RUN )); then
        printf '  + disable Arch Update autostart because arch-update is not installed\n'
    else
        sed -i '/^[[:space:]]*Hidden=/d' "$file"
        printf '%s\n' 'Hidden=true' >> "$file"
        chown "$TARGET_USER:$(id -gn "$TARGET_USER")" "$file"
        chmod 0644 "$file"
    fi
    warn "Arch Update was unavailable; its tray autostart entry was disabled"
}

configure_dolphin_status_bar() {
    command -v kwriteconfig6 >/dev/null 2>&1 || {
        warn "kwriteconfig6 is unavailable; Dolphin full-width status bar was not configured"
        return 0
    }
    backup_path "$TARGET_HOME/.config/dolphinrc"
    run install -d -m 0755 -o "$TARGET_USER" -g "$(id -gn "$TARGET_USER")" \
        "$TARGET_HOME/.config"
    run runuser -u "$TARGET_USER" -- kwriteconfig6 \
        --file "$TARGET_HOME/.config/dolphinrc" \
        --group General --key ShowStatusBar FullWidth

    backup_path /etc/skel/.config/dolphinrc
    run install -d -m 0755 /etc/skel/.config
    run kwriteconfig6 --file /etc/skel/.config/dolphinrc \
        --group General --key ShowStatusBar FullWidth
    log "Configured Dolphin to use the full-width status bar"
}

configure_vivaldi_preferences() {
    local profile_dir="$TARGET_HOME/.config/vivaldi/Default"
    local preferences="$profile_dir/Preferences"
    local defaults="$SCRIPT_DIR/vivaldi-defaults.json"
    local temporary
    local had_profile=0

    [[ -f $defaults ]] || die "payload is missing vivaldi-defaults.json"
    [[ -e $preferences ]] && had_profile=1

    if (( had_profile && ! APPLY_VIVALDI_DEFAULTS )); then
        log "Preserving the existing Vivaldi profile and preferences"
        return 0
    fi
    if pgrep -u "$TARGET_USER" -f '(/|^)vivaldi-bin([[:space:]]|$)' >/dev/null 2>&1; then
        warn "Vivaldi is running; MyLastArch new-tab and search defaults were not applied. Close Vivaldi and run the converter again to apply them safely."
        return 0
    fi
    command -v jq >/dev/null 2>&1 || {
        warn "jq is unavailable; Vivaldi preferences were preserved"
        return 0
    }

    backup_path "$preferences"
    if (( DRY_RUN )); then
        printf '  + merge MyLastArch new-tab and DuckDuckGo defaults into %s\n' "$preferences"
        return 0
    fi

    install -d -m 0700 -o "$TARGET_USER" -g "$(id -gn "$TARGET_USER")" "$profile_dir"
    temporary=$(mktemp)
    if [[ -f $preferences ]]; then
        jq -s '.[0] * .[1]' "$preferences" "$defaults" > "$temporary"
    else
        jq . "$defaults" > "$temporary"
    fi
    install -m 0600 -o "$TARGET_USER" -g "$(id -gn "$TARGET_USER")" "$temporary" "$preferences"
    rm -f -- "$temporary"
    log "Applied the MyLastArch Vivaldi new-tab and DuckDuckGo defaults"
}

configure_grub() {
    (( CONFIGURE_GRUB )) || return 0
    if ! command -v grub-mkconfig >/dev/null || [[ ! -d /boot/grub ]]; then
        warn "GRUB is not the active boot loader; GRUB customization was skipped"
        return 0
    fi
    log "Applying MyLastArch GRUB behavior and update hooks"
    backup_path /etc/default/grub
    if (( DRY_RUN )); then
        printf '  + merge MyLastArch settings into /etc/default/grub\n'
    else
        local key value
        while IFS='=' read -r key value; do
            [[ $key =~ ^GRUB_(DEFAULT|TIMEOUT|DISTRIBUTOR|CMDLINE_LINUX_DEFAULT|TIMEOUT_STYLE|GFXMODE|GFXPAYLOAD_LINUX|DISABLE_RECOVERY|SAVEDEFAULT|DISABLE_SUBMENU|DISABLE_OS_PROBER)$ ]] || continue
            sed -i "/^${key}=/d" /etc/default/grub
            printf '%s=%s\n' "$key" "$value" >> /etc/default/grub
        done < "$AIROOTFS/etc/default/grub"
    fi
    copy_system_file usr/local/sbin/mylastarch-grub-kernel-titles 755
    copy_system_file usr/local/sbin/mylastarch-refresh-grub 755
    copy_system_file etc/pacman.d/hooks/95-mylastarch-grub-kernel-titles.hook
    copy_system_file etc/pacman.d/hooks/97-mylastarch-refresh-grub.hook
    run /usr/local/sbin/mylastarch-grub-kernel-titles
    run grub-mkconfig -o /boot/grub/grub.cfg
}

trap cleanup_on_exit EXIT

phase "Repository setup" \
    "Trusting the MyLastArch signing key when needed" \
    "Enabling and synchronizing the MyLastArch repository"
configure_repo

phase "KDE and desktop foundation" \
    "Installing Plasma, Cairo-Dock, themes, audio, Bluetooth, and printing"
install_available_packages "$SCRIPT_DIR/packages-core.txt" core
configure_mdns_resolution
if (( INSTALL_APPS )); then
    phase "Application collection" \
        "Installing the optional applications shipped by MyLastArch"
    install_available_packages "$SCRIPT_DIR/packages-apps.txt" optional
    phase "Optional community applications" \
        "Installing repository packages first" \
        "Using Yay only for packages unavailable through pacman"
    install_community_packages
    cleanup_new_build_dependencies
fi

phase "MyLastArch system assets" \
    "Installing branding, wallpaper, Dolphin actions, hooks, and services"
copy_system_file etc/mylastarch-release
copy_system_file usr/share/wallpapers/MyLastArch/metadata.desktop
copy_system_file usr/share/wallpapers/MyLastArch/contents/config
copy_system_file usr/share/wallpapers/MyLastArch/contents/images/mylastarch.png
copy_system_file usr/share/backgrounds/mylastarch/xscreensaver-images/clouds.jpg
copy_system_file usr/local/bin/mylastarch-dolphin-action 755
copy_system_file usr/share/kio/servicemenus/mylastarch-actions.desktop 755
copy_system_file usr/share/kio/servicemenus/mylastarch-convert-image.desktop 755
copy_system_file usr/share/kio/servicemenus/mylastarch-hidden-files.desktop 755
copy_system_file usr/local/sbin/mylastarch-arch-update-safety 755
copy_system_file etc/systemd/system/mylastarch-arch-update-safety.service
copy_system_file etc/pacman.d/hooks/96-mylastarch-arch-update-safety.hook

phase "Desktop configuration for $TARGET_USER" \
    "Backing up the current desktop configuration" \
    "Applying the top panel, splash, wallpaper, and Cairo-Dock settings" \
    "Installing defaults for future users"
stop_plasma_if_running
backup_path "$TARGET_HOME/.config"
backup_path "$TARGET_HOME/.xscreensaver"
run rsync -a --exclude='calamares.desktop' --exclude='Desktop/' --exclude='import-mylastarch-key.sh' --exclude='dolphinrc' --exclude='.config/vivaldi/' --chown="$TARGET_USER:$(id -gn "$TARGET_USER")" "$AIROOTFS/etc/skel/" "$TARGET_HOME/"
disable_competing_plank
disable_missing_arch_update_autostart
backup_path /etc/skel
run rsync -a --exclude='calamares.desktop' --exclude='Desktop/' --exclude='import-mylastarch-key.sh' --exclude='dolphinrc' --exclude='.config/vivaldi/' "$AIROOTFS/etc/skel/" /etc/skel/
configure_dolphin_status_bar
configure_vivaldi_preferences
restart_plasma_if_needed

phase "System services and display manager" \
    "Enabling Bluetooth, printing, discovery, and MyLastArch safeguards" \
    "Preserving the display manager by default or migrating SDDM when requested" \
    "Applying the MyLastArch login background when Plasma Login Manager is active"
enable_if_available bluetooth.service
enable_if_available cups.service
enable_if_available avahi-daemon.service
enable_if_available mylastarch-arch-update-safety.service
enable_display_manager
configure_plasma_login_manager

phase "Boot loader configuration" \
    "Preserving the existing bootloader by default" \
    "Applying MyLastArch GRUB behavior only with --configure-grub"
configure_grub

phase "Package source cleanup" \
    "Removing a temporarily enabled MyLastArch repository when requested" \
    "Leaving installed package signatures and the trusted signing key intact"
remove_temporary_repo

phase "Finalizing the conversion" \
    "Writing the completion marker" \
    "Showing the reboot and validation instructions"
if (( ! DRY_RUN )); then
    printf 'ConvertedBy=mylastarch-converter\nConvertedAt=%s\n' "$(date --iso-8601=seconds)" > /etc/mylastarch-conversion
fi

log "Conversion complete"
printf 'Backup: %s\n' "$BACKUP"
show_package_source_summary
if command -v strawberry >/dev/null 2>&1; then
    warn "STRAWBERRY FIRST-USE STEP: Open Strawberry, select Subsonic at the bottom of the left sidebar, and refresh the catalog before playing music."
fi
NOTICE=$YELLOW
printf '\n%b%s%b\n' "$NOTICE" '====================================================================' "$RESET"
printf '%b  IMPORTANT: REBOOT TO FINISH APPLYING THE MYLASTARCH CHANGES%b\n' "$NOTICE" "$RESET"
printf '%b%s%b\n' "$NOTICE" '====================================================================' "$RESET"
printf 'A reboot is recommended so services, Plasma, Cairo-Dock, and system\n'
printf 'settings all start cleanly. Logging out and back in is sufficient for\n'
printf 'most desktop-only changes.\n\n'
printf 'OPTIONAL READ-ONLY CHECK AFTER REBOOT:\n'
printf '  %s/validate-mylastarch.sh --user %s\n' "$SCRIPT_DIR" "$TARGET_USER"
printf 'Validation only reports [OK] or [FAIL]; it does not change the system.\n'
