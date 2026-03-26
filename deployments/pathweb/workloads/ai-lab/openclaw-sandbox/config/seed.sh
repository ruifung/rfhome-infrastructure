#!/bin/bash
set -e
TARGET="/mnt/persist/rootfs"
PROOT_URL="https://github.com/proot-me/proot/releases/download/v5.4.0/proot-v5.4.0-x86_64-static"

# Install dependencies if missing
if ! command -v curl >/dev/null || ! command -v debootstrap >/dev/null; then
    apt-get update
    apt-get install -y curl debootstrap
fi

# Download static proot
if [ ! -f "/mnt/persist/proot" ]; then
    echo "Downloading static proot..."
    curl -L "$PROOT_URL" -o "/mnt/persist/proot"
    chmod +x "/mnt/persist/proot"
    chown 1000:1000 "/mnt/persist/proot"
fi

if [ ! -f "$TARGET/etc/debian_version" ]; then
    echo "Initializing new rootfs in $TARGET..."
    debootstrap --variant=minbase stable "$TARGET" http://deb.debian.org/debian

    # Use proot for initial configuration of the chroot
    PROOT="/mnt/persist/proot"

    # We run these as root (host) to set up the rootfs
    # But we want the final files to be owned by 1000 for proot -0 usage
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys groupadd -g 1000 openclaw
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys useradd -u 1000 -g 1000 -m -s /bin/bash openclaw
    echo "openclaw:openclaw" | $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys chpasswd

    # Pre-install some useful tools
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys apt-get update
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys apt-get install -y sudo bash-completion vim-nox curl wget git python3

    # Allow sudo without password for openclaw
    echo "openclaw ALL=(ALL) NOPASSWD:ALL" > "$TARGET/etc/sudoers.d/openclaw"
    chmod 0440 "$TARGET/etc/sudoers.d/openclaw"

    # Fix ownership so the host user 1000 can use it with proot -0
    echo "Fixing ownership..."
    chown -R 1000:1000 "$TARGET"
else
    echo "Existing rootfs found in $TARGET. Skipping initialization."
    # Ensure ownership is correct even on existing rootfs
    chown -R 1000:1000 "$TARGET" || true
fi
