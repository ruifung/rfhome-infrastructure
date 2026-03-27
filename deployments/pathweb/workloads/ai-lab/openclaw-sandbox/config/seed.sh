#!/bin/sh
set -e
TARGET="/mnt/persist/rootfs"
PROOT_URL="https://proot.gitlab.io/proot/bin/proot"
ROOTFS_URL="https://images.linuxcontainers.org/images/debian/trixie/amd64/default/20260326_05%3A24/rootfs.tar.xz"
HASH_FILE="/mnt/persist/seed.hash"

# Function to calculate current config hash
# Includes the URLs and the basic setup commands to detect changes
calc_hash() {
    echo "$PROOT_URL|$ROOTFS_URL" | sha256sum | cut -d' ' -f1
}

CURRENT_HASH=$(calc_hash)
NEED_RESEED=false

if [ ! -f "$TARGET/etc/debian_version" ]; then
    echo "Rootfs missing. Initializing..."
    NEED_RESEED=true
elif [ ! -f "$HASH_FILE" ] || [ "$(cat "$HASH_FILE")" != "$CURRENT_HASH" ]; then
    echo "Config change detected. Re-initializing rootfs..."
    NEED_RESEED=true
fi

if [ "$NEED_RESEED" = "true" ]; then
    mkdir -p /mnt/persist/ssh

    # Download static proot if missing
    if [ ! -f "/mnt/persist/proot" ]; then
        echo "Downloading static proot..."
        wget "$PROOT_URL" -O "/mnt/persist/proot"
        chmod +x "/mnt/persist/proot"
    fi

    PROOT="/mnt/persist/proot"

    echo "Initializing new rootfs in $TARGET..."
    # Clean up old rootfs if it exists
    rm -rf "$TARGET"
    mkdir -p "$TARGET"

    echo "Downloading rootfs tarball..."
    wget "$ROOTFS_URL" -O "/mnt/persist/rootfs.tar.xz"

    echo "Extracting rootfs via PRoot..."
    $PROOT -0 tar -xf /mnt/persist/rootfs.tar.xz -C "$TARGET"
    rm /mnt/persist/rootfs.tar.xz

    echo "Configuring sandbox environment..."
    # Setup basic users and groups in chroot using proot
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys groupadd -g 1000 openclaw || true
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys useradd -u 1000 -g 1000 -m -s /bin/bash openclaw || true

    # Pre-install base tools (switching to dropbear-bin for non-root compatibility)
    echo "Updating and installing base tools (within PRoot)..."
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts apt-get update
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts apt-get install -y sudo bash-completion vim-nox curl wget git python3 dropbear-bin

    # Allow sudo without password for openclaw
    echo "openclaw ALL=(ALL) NOPASSWD:ALL" > "$TARGET/etc/sudoers.d/openclaw"
    chmod 0440 "$TARGET/etc/sudoers.d/openclaw"

    # Store the hash to prevent redundant re-initialization
    echo "$CURRENT_HASH" > "$HASH_FILE"
    echo "Initialization complete."
else
    echo "Existing rootfs found and hash matches. Skipping initialization."
fi
