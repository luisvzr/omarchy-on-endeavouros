#!/bin/bash
set -e

# Omarchy on EndeavourOS
# Adapts the Omarchy installer for EndeavourOS with systemd-boot.
# Inspired by https://github.com/mroboff/omarchy-on-cachyos

OMARCHY_REPO="basecamp/omarchy"
OMARCHY_REF="master"
OMARCHY_DIR="$HOME/.local/share/omarchy"

echo ""
echo "  Omarchy on EndeavourOS"
echo "  ─────────────────────────────────────────────"
echo ""

# ── 1. Set up omarchy mirror ──────────────────────────────────────────────────
echo "[1/7] Configuring Omarchy package mirror..."
echo 'Server = https://stable-mirror.omarchy.org/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist >/dev/null
sudo pacman -Syu --noconfirm --needed git

# ── 2. Clone Omarchy ──────────────────────────────────────────────────────────
echo "[2/7] Cloning Omarchy..."
rm -rf "$OMARCHY_DIR"
git clone "https://github.com/${OMARCHY_REPO}.git" "$OMARCHY_DIR" --quiet
cd "$OMARCHY_DIR"
git fetch origin "$OMARCHY_REF" && git checkout "$OMARCHY_REF" --quiet
cd -

# ── 3. Patch: skip limine-snapper (bootloader already managed by systemd-boot) ─
echo "[3/7] Patching: removing limine-snapper step..."
sed -i '/limine-snapper\.sh/d' "$OMARCHY_DIR/install/login/all.sh"

# ── 4. Patch: suppress wireless regdom error on wired-only / VM systems ────────
echo "[4/7] Patching: suppressing nl80211 wireless error..."
sed -i 's/sudo iw reg set \${COUNTRY}/sudo iw reg set ${COUNTRY} 2>\/dev\/null || true/' \
    "$OMARCHY_DIR/install/config/hardware/set-wireless-regdom.sh"

# ── 5. Patch: remove conflicting kernel-install-for-dracut ────────────────────
echo "[5/7] Removing conflicting package: kernel-install-for-dracut..."
if pacman -Q kernel-install-for-dracut &>/dev/null; then
    sudo pacman -R --noconfirm kernel-install-for-dracut
fi

# ── 6. Set up Limine (required by Omarchy for snapshot boot entries) ──────────
echo "[6/7] Setting up Limine bootloader alongside systemd-boot..."

# Detect ESP mount point
ESP=$(bootctl -p 2>/dev/null || echo "/efi")

sudo pacman -S --noconfirm --needed limine

# Install Limine EFI binary
sudo mkdir -p "$ESP/EFI/limine"
sudo cp /usr/share/limine/BOOTX64.EFI "$ESP/EFI/limine/BOOTX64.EFI"

# Add EFI boot entry for Limine (won't duplicate if already present)
DISK=$(lsblk -no PKNAME "$(findmnt -n -o SOURCE "$ESP")" | head -1)
PART=$(lsblk -no PARTN "$(findmnt -n -o SOURCE "$ESP")")
if ! efibootmgr | grep -q "Limine"; then
    sudo efibootmgr --create --disk "/dev/$DISK" --part "$PART" \
        --label "Limine" --loader /EFI/limine/BOOTX64.EFI --quiet
fi

# Install limine-mkinitcpio-hook and limine-snapper-sync from Omarchy repo
sudo pacman -S --noconfirm --needed limine-mkinitcpio-hook limine-snapper-sync

# Fix default.conf ESP path to match actual ESP mount point
OMARCHY_LIMINE_CONF="$OMARCHY_DIR/default/limine/default.conf"
if [[ -f "$OMARCHY_LIMINE_CONF" ]]; then
    sudo sed -i "s|ESP_PATH=.*|ESP_PATH=\"$ESP\"|" "$OMARCHY_LIMINE_CONF"
fi

# Symlink /boot/limine.conf -> $ESP/limine.conf so Omarchy's checks pass
if [[ "$ESP" != "/boot" ]] && [[ -f "$ESP/limine.conf" ]]; then
    sudo rm -f /boot/limine.conf
    sudo ln -s "$ESP/limine.conf" /boot/limine.conf
elif [[ "$ESP" != "/boot" ]]; then
    # Run limine-update to generate $ESP/limine.conf, then symlink
    sudo limine-update 2>/dev/null || true
    if [[ -f "$ESP/limine.conf" ]]; then
        sudo rm -f /boot/limine.conf
        sudo ln -s "$ESP/limine.conf" /boot/limine.conf
    fi
fi

# ── 7. Fix DNS (systemd-resolved + resolv.conf symlink) ──────────────────────
echo "[7/8] Fixing DNS: enabling systemd-resolved..."
sudo systemctl enable --now systemd-resolved
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl restart NetworkManager

# ── 8. Run Omarchy install ────────────────────────────────────────────────────
echo "[8/8] Starting Omarchy installation..."
export OMARCHY_ONLINE_INSTALL=true
source "$OMARCHY_DIR/install.sh"
