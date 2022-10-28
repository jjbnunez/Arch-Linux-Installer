#!/bin/bash

pacman-key --init
pacman-key --populate

# REMINDER: Never run pacman -Sy on your system!
pacman -Sy dialog --noconfirm

# Enable automatic synchronization of the system clock with NTP. 
timedatectl set-ntp true

# Warn the user that this script will wipe a hard drive.
dialog --defaultno --title "WARNING" --yesno \
"Hi! My name is JJ Nunez. \n\n\
This is my personal Arch Linux installer script. \n\n\
This script will DESTROY EVERYTHING on one of your drives. \n\n\
If you're not sure what you're doing, please select NO. \n\n\
Otherwise, proceed with the installation! \n\n\
Do you want to continue?" 15 60 || exit

# Prompt the user for a hostname.
dialog --no-cancel --inputbox "Enter a hostname for your computer:" \
    10 60 2> comp

# Read the hostname in as a variable.
comp=$(cat comp) && rm comp

# Verify boot type (UEFI or BIOS).
uefi=0
ls /sys/firmware/efi/efivars 2> /dev/null && uefi=1

# Collect a list of storage devices.
devices_list=($(lsblk -d | awk '{print "/dev/" $1 " " $4 " on"}' \
    | grep -E 'sd|hd|vd|nvme|mmcblk'))

# Prompt the user to select one of the storage devices.
dialog --title "Choose your drive" --no-cancel --radiolist \
"Where do you want to install the system? \n\n\
Select a device with SPACE, and confirm your selection with ENTER. \n\n\
WARNING: Everything will be DESTROYED on the drive you select!" \
15 60 4 "${devices_list[@]}" 2> hd

# Read the drive in as a variable.
hd=$(cat hd) && rm hd

# Prompt the user to input a swap partition size in GiB.
default_size="8"
dialog --no-cancel --inputbox \
"You need three partitions: Boot, Root, and Swap \n\
The boot partition will be 512M \n\
The root partition will take up most of the remaining space on your drive \n\n\
Enter below the desired partition size (in Gb) for the swap partition. \n\n\
If you don't enter anything, it will default to ${default_size}G. \n" \
20 60 2> swap_size

# Read the swap partition size in as a variable.
size=$(cat swap_size) && rm swap_size

# If the user did not enter a swap partition size, use the default.
[[ $size =~ ^[0-9]+$ ]] || size=$default_size

# Prompt the user to wipe the drive
dialog --no-cancel \
--title "!!! DELETE EVERYTHING !!!" \
--menu "Choose the way you'll wipe your disk ($hd)" \
15 60 4 \
1 "Use dd (basic wipe)" \
2 "Use shred (slow & secure)" \
3 "No need - my drive is empty" 2> eraser

# Read the drive eraser method in as a variable.
hderaser=$(cat eraser); rm eraser

# Define a function to erase (or skip erasing) a given drive.
function eraseDisk() {
    case $1 in
        1) dd if=/dev/zero of="$hd" status=progress 2>&1 \
            | dialog \
            --title "Formatting $hd..." \
            --progressbox --stdout 20 60;;
        2) shred -v "$hd" \
            | dialog \
            --title "Formatting $hd..." \
            --progressbox --stdout 20 60;;
        3) ;;
    esac
}

# DANGEROUS: erase the disk.
eraseDisk "$hderaser"

# Determine boot partition type before running fdisk.
boot_partition_type=1
[[ "$uefi" == 0 ]]  && boot_partition_type=4

# Create the partitions

#g - create non empty GPT partition table
#n - create new partition
#p - primary partition
#e - extended partition
#w - write the table to disk and exit

partprobe "$hd"

fdisk "$hd" << EOF
g
n


+512M
t
$boot_partition_type
n


+${size}G
n



w
EOF

partprobe "$hd"

# Format the partitions

mkswap "${hd}2"
swapon "${hd}2"

mkfs.ext4 "${hd}3"
mount "${hd}3" /mnt

if [ "$uefi" = 1 ]; then
    mkfs.fat -F32 "${hd}1"
    mkdir -p /mnt/boot/efi
    mount "${hd}1" /mnt/boot/efi
fi

pacstrap /mnt base base-devel linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

# Persist important values for the next script
echo "$uefi" > /mnt/var_uefi
echo "$hd" > /mnt/var_hd
echo "$comp" > /mnt/comp

curl https://raw.githubusercontent.com/jjbnunez\
/Arch-Linux-Installer/main/install_chroot.sh > /mnt/install_chroot.sh

arch-chroot /mnt bash install_chroot.sh

rm /mnt/var_uefi
rm /mnt/var_hd
rm /mnt/install_chroot.sh
rm /mnt/comp

dialog --title "To reboot or not to reboot?" --yesno \
"Congrats! The install is done! \n\n\
Do you want to reboot your computer?" 20 60

response=$?

case $response in
    0) reboot;;
    1) clear;;
esac
