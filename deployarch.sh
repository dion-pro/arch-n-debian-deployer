#!/bin/bash

# Check for sufficient arguments
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <snapshot_path> <root_partition> <boot_mode> [efi_partition]"
    echo "Example for UEFI: $0 /path/to/backup/system.tar.gz /dev/sdX2 uefi /dev/sdX1"
    echo "Example for BIOS: $0 /path/to/backup/system.tar.gz /dev/sdX1 bios"
    exit 1
fi

# Variables from script parameters
SNAPSHOT_PATH="$1"
ROOT_PARTITION="$2"
BOOT_MODE="$3"
EFI_PARTITION="$4"

# Check if the snapshot path exists
if [ ! -f "$SNAPSHOT_PATH" ]; then
    echo "Error: Snapshot path ${SNAPSHOT_PATH} does not exist."
    exit 1
fi

# Prompt for bootloader choice
echo "Choose a bootloader:"
echo "1) GRUB"
echo "2) systemd-boot (UEFI only)"
echo "3) Syslinux"
read -p "Enter the number of your choice: " BOOTLOADER_CHOICE

# Prepare and mount the root partition
echo "Formatting and mounting root partition..."
mkfs.ext4 ${ROOT_PARTITION}
mount ${ROOT_PARTITION} /mnt

if [ "$BOOT_MODE" == "uefi" ]; then
    echo "Formatting EFI partition..."
    mkfs.fat -F32 ${EFI_PARTITION}
    mkdir -p /mnt/boot/efi
    mount ${EFI_PARTITION} /mnt/boot/efi
fi

# Extract the snapshot
echo "Extracting snapshot..."
tar -xzvf "${SNAPSHOT_PATH}" -C /mnt

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Install and configure the bootloader
echo "Configuring bootloader..."
if [ "$BOOT_MODE" == "uefi" ]; then
    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys
    mount --bind /run /mnt/run
    case $BOOTLOADER_CHOICE in
        1)  # GRUB
            arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch
            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
            ;;
        2)  # systemd-boot
            arch-chroot /mnt bootctl --no-variables install
            ;;
        3)  # Syslinux
            # Copy Syslinux files
            arch-chroot /mnt mkdir -p /boot/efi/EFI/syslinux
            arch-chroot /mnt cp -r /usr/lib/syslinux/efi64/* /boot/efi/EFI/syslinux
            # Create UEFI boot entry
            arch-chroot /mnt efibootmgr --create --disk ${EFI_PARTITION} --part 1 --loader /EFI/syslinux/syslinux.efi --label "Syslinux" --unicode
            ;;
        *)  # Invalid choice
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    umount /mnt/run
    umount /mnt/sys
    umount /mnt/proc
    umount /mnt/dev
    umount /mnt/boot/efi
else
    # BIOS mode
    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys
    mount --bind /run /mnt/run
    case $BOOTLOADER_CHOICE in
        1)  # GRUB
            arch-chroot /mnt grub-install --target=i386-pc ${ROOT_PARTITION}
            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
            ;;
        3)  # Syslinux
            arch-chroot /mnt syslinux-install_update -i -a -m
            ;;
        2)  # systemd-boot in BIOS mode defaults to GRUB
            echo "systemd-boot is not supported in BIOS mode. Defaulting to GRUB."
            arch-chroot /mnt grub-install --target=i386-pc ${ROOT_PARTITION}
            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
            ;;
        *)  # Invalid choice
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    umount /mnt/run
    umount /mnt/sys
    umount /mnt/proc
    umount /mnt/dev
fi

# Unmount and reboot
umount /mnt
echo "Deployment complete. Rebooting..."
