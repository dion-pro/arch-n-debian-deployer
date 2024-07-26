#!/bin/bash

pacman -Sy

# Function to prompt user for input with default values
prompt() {
    local prompt_text="$1"
    local default_value="$2"
    local user_input
    read -p "$prompt_text [$default_value]: " user_input
    echo "${user_input:-$default_value}"
}

# Function to check command success
check_success() {
    if [ $? -ne 0 ]; then
        echo "Error occurred during $1. Exiting."
        exit 1
    fi
}

# Get user input
DISK=$(prompt "Enter the disk to install Arch Linux on (e.g., /dev/sda)" "/dev/sda")
MOUNT_POINT=$(prompt "Enter the mount point for the root partition" "/mnt")
HOSTNAME=$(prompt "Enter the hostname for the system" "archlinux")
LOCALE=$(prompt "Enter the locale (e.g., en_US.UTF-8)" "en_US.UTF-8")
TIMEZONE=$(prompt "Enter the timezone (e.g., CONTINENT/CITY)" "UTC")
ROOT_PASSWORD=$(prompt "Enter the root password" "rootpassword")
USER_NAME=$(prompt "Enter the username for a new user" "user")
USER_PASSWORD=$(prompt "Enter the password for the new user" "userpassword")
KERNEL=$(prompt "Enter the kernel to install (e.g., linux, linux-lts, linux-zen)" "linux")

# Check if the kernel exists in the repositories
if ! pacman -Si $KERNEL > /dev/null 2>&1; then
    echo "Error: The kernel '$KERNEL' is not available in the repositories. Exiting."
    exit 1
fi

# Detect boot mode
UEFI=$(ls /sys/firmware/efi/efivars > /dev/null 2>&1 && echo 1 || echo 0)

# Partition the disk
echo "Partitioning the disk..."
parted $DISK mklabel gpt
check_success "disk partitioning"

if [ "$UEFI" -eq 1 ]; then
    parted $DISK mkpart primary fat32 1MiB 512MiB
    parted $DISK set 1 esp on
    parted $DISK mkpart primary ext4 512MiB 100%
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
else
    parted $DISK mkpart primary ext4 1MiB 100%
    ROOT_PART="${DISK}1"
fi
check_success "creating partitions"

# Format partitions
echo "Formatting partitions..."
if [ "$UEFI" -eq 1 ]; then
    mkfs.fat -F32 $EFI_PART
    check_success "formatting EFI partition"
fi
mkfs.ext4 $ROOT_PART
check_success "formatting root partition"

# Mount the partitions
echo "Mounting partitions..."
mount $ROOT_PART $MOUNT_POINT
check_success "mounting root partition"

if [ "$UEFI" -eq 1 ]; then
    mkdir -p $MOUNT_POINT/boot
    mount $EFI_PART $MOUNT_POINT/boot
    check_success "mounting EFI partition"
fi

# Install base system
echo "Installing base system..."
pacstrap $MOUNT_POINT base $KERNEL linux-firmware networkmanager nano sudo
check_success "base system installation"

# Generate fstab
echo "Generating fstab..."
genfstab -U $MOUNT_POINT >> $MOUNT_POINT/etc/fstab
check_success "generating fstab"

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
pacman -S --noconfirm grub
check_success "GRUB installation"

if [ "$UEFI" -eq 1 ]; then
    pacman -S --noconfirm efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch
else
    grub-install --target=i386-pc $DISK
fi
check_success "GRUB installation to disk"

# Generate GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg
check_success "GRUB configuration generation"

EOF

# Unmount partitions and reboot
echo "Unmounting partitions and rebooting..."
umount -R $MOUNT_POINT
check_success "unmounting partitions"

echo "Installation complete. Rebooting now..."
reboot