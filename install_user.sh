#!/bin/bash

mkdir -p "/home/$(whoami)/Documents"
mkdir -p "/home/$(whoami)/Downloads"

# Uncomment to set the keymap you want. Replace "fr" with your country code
#localectl --no-convert set-x11-keymap fr

# A function that can install any package from the AUR without using `yay`
aur_install() {
    curl -O "https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz" \
    && tar -xvf "$1.tar.gz" \
    && cd "$1" \
    && makepkg --noconfirm -si \
    && cd - \
    && rm -rf "$1" "$1.tar.gz"
}

# A function that tries to install an AUR package using `yay`
# If `yay` is not yet present, it installs the package using
# the above `aur_install()` shellscript function
aur_check() {
    qm=$(pacman -Qm | awk '{print $1}')
    for arg in "$@"
    do
        if [[ "$qm" != *"$arg"* ]]; then
            yay --noconfirm -S "$arg" &>> /tmp/aur_install \
                || aur_install "$arg" &>> /tmp/aur_install
        fi
    done
}

cd /tmp
dialog --infobox "Installing \"Yay\", an AUR helper..." 10 60
aur_check yay

count=$(wc -l < /tmp/aur_queue)
c=0

cat /tmp/aur_queue | while read -r line
do
    c=$(( "$c" + 1 ))
    dialog --infobox \
    "AUR install - Downloading and installing program $c out of $count: $line..." \
    10 60
    aur_check "$line"
done

DOTFILES="/home/$(whoami)/dotfiles"
if [ ! -d "$DOTFILES" ]; then
    git clone https://github.com/jjbnunez/dotfiles.git \
    "$DOTFILES" >/dev/null
fi

source "$DOTFILES/zsh/.zshenv"
cd "$DOTFILES" && bash install.sh
