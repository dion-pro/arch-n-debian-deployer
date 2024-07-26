#!/bin/bash

# Variables
DISK="/dev/sda"                 # Adjust to your target disk
MOUNT_POINT="/mnt"
HOSTNAME="arch"
LOCALE="en_US.UTF-8"
TIMEZONE="America/New_York"
ROOT_PASSWORD="toor"   # Change this to a secure password
USER_NAME="user"
USER_PASSWORD="resu"   # Change this to a secure password

# Partition the disk
echo "Partitioning the disk..."
parted $DISK mklabel gpt
parted $DISK mkpart primary fat32 1MiB 512MiB
parted $DISK set 1 esp on
parted $DISK mkpart primary ext4 512MiB 100%

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 ${DISK}1
mkfs.ext4 ${DISK}2

# Mount the partitions
echo "Mounting partitions..."
mount ${DISK}2 $MOUNT_POINT
mkdir -p $MOUNT_POINT/boot
mount ${DISK}1 $MOUNT_POINT/boot

# Install base system
echo "Installing base system..."
pacstrap $MOUNT_POINT base linux linux-firmware

# Generate fstab
echo "Generating fstab..."
genfstab -U $MOUNT_POINT >> $MOUNT_POINT/etc/fstab

# Chroot into the new system
echo "Chrooting into the new system..."
arch-chroot $MOUNT_POINT /bin/bash <<EOF
# Set timezone and locale
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname
cat <<EOL >> /etc/hosts
127.0.0.1       localhost
::1             localhost
127.0.1.1       $HOSTNAME.localdomain  $HOSTNAME
EOL

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Create a new user
useradd -m -G wheel $USER_NAME
echo "$USER_NAME:$USER_PASSWORD" | chpasswd
echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER_NAME

# Install and configure GRUB
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# Unmount partitions and reboot
echo "Unmounting partitions and rebooting..."
umount -R $MOUNT_POINT
reboot
