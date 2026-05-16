# Omarchy on EndeavourOS

Installs [Omarchy](https://github.com/basecamp/omarchy) on EndeavourOS (or any Arch-based system using systemd-boot).

Inspired by [omarchy-on-cachyos](https://github.com/mroboff/omarchy-on-cachyos).

## What it does

Omarchy assumes a fresh Arch install with Limine as the bootloader. EndeavourOS ships with systemd-boot (or GRUB). This adapter bridges the gap:

| Patch | Why |
|---|---|
| Skip `limine-snapper.sh` | Omarchy uses this for snapshot boot entries; we keep systemd-boot and add Limine as a secondary bootloader for snapshots |
| Suppress `nl80211` error | Wireless regdom setup fails on wired-only machines and VMs — non-fatal |
| Remove `kernel-install-for-dracut` | Conflicts with `mkinitcpio` which Omarchy requires |
| Install Limine alongside systemd-boot | Omarchy's `limine-mkinitcpio-hook` and `limine-snapper-sync` need it |
| Fix `ESP_PATH` | EndeavourOS mounts the ESP at `/efi`, not `/boot` |
| Symlink `/boot/limine.conf → $ESP/limine.conf` | Omarchy checks `/boot/limine.conf` but Limine writes to `$ESP/limine.conf` |

## Usage

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/luisvzr/omarchy-on-endeavouros/main/install.sh)
```

Or manually:

```bash
git clone https://github.com/luisvzr/omarchy-on-endeavouros.git
bash omarchy-on-endeavouros/install.sh
```

## Requirements

- EndeavourOS (or Arch-based distro) with systemd-boot
- UEFI system
- Internet connection

## Notes

- Limine is installed **alongside** systemd-boot — your existing boot entries are preserved
- Omarchy's snapshot boot menu (limine-snapper-sync) will work via Limine
- After install, both Limine and systemd-boot entries appear in your firmware boot menu
