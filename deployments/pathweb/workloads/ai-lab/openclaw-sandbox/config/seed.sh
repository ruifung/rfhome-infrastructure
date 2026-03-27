#!/bin/sh
set -e
TARGET="/mnt/persist/rootfs"
PROOT_URL="https://proot.gitlab.io/proot/bin/proot"
# Using a minimal Debian rootfs tarball to avoid debootstrap privilege issues
ROOTFS_URL="https://images.linuxcontainers.org/images/debian/trixie/amd64/default/20260326_05%3A24/rootfs.tar.xz"

mkdir -p /mnt/persist/ssh

# Download static proot if missing
if [ ! -f "/mnt/persist/proot" ]; then
    echo "Downloading static proot..."
    wget "$PROOT_URL" -O "/mnt/persist/proot"
    chmod +x "/mnt/persist/proot"
fi

PROOT="/mnt/persist/proot"

if [ ! -f "$TARGET/etc/debian_version" ]; then
    echo "Initializing new rootfs in $TARGET..."
    mkdir -p "$TARGET"
    echo "Downloading rootfs tarball..."
    wget "$ROOTFS_URL" -O "/mnt/persist/rootfs.tar.xz"

    echo "Extracting rootfs via PRoot..."
    # We use -0 to fake root ownership during extraction into the PVC
    $PROOT -0 tar -xf /mnt/persist/rootfs.tar.xz -C "$TARGET"
    rm /mnt/persist/rootfs.tar.xz

    echo "Configuring sandbox environment..."
    # Setup basic users and groups in chroot using proot
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys groupadd -g 1000 openclaw || true
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys useradd -u 1000 -g 1000 -m -s /bin/bash openclaw || true

    # Setup sshd privilege separation user
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys useradd -r -d /run/sshd -s /usr/sbin/nologin sshd || true

    # Pre-install some useful tools into the rootfs
    echo "Updating and installing base tools (within PRoot)..."
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts apt-get update
    $PROOT -0 -r "$TARGET" -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts apt-get install -y sudo bash-completion vim-nox curl wget git python3 openssh-server

    # Allow sudo without password for openclaw
    echo "openclaw ALL=(ALL) NOPASSWD:ALL" > "$TARGET/etc/sudoers.d/openclaw"
    chmod 0440 "$TARGET/etc/sudoers.d/openclaw"

    echo "Fixing ownership for non-root usage..."
    chown -R 1000:1000 "$TARGET"
else
    echo "Existing rootfs found in $TARGET. Skipping initialization."
    chown -R 1000:1000 "$TARGET" || true
fi
