#!/bin/sh
set -e
CHROOT_PATH="/persist/rootfs"
PROOT="/persist/proot"

# Generate host keys inside the persistent rootfs if they don't exist
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys ssh-keygen -A
# Ensure host keys have correct permissions (sshd is very strict about this)
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 755 /etc/ssh || true
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 600 /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ed25519_key || true

# Manage runtime SSH key for authentication (for the openclaw user)
# We store these on the PVC so they can be shared with the main OpenClaw pod
mkdir -p /persist/ssh
if [ ! -f /persist/ssh/id_ed25519 ]; then
    echo "Generating new runtime SSH keypair..."
    # Ensure the home/ssh directory exists inside the rootfs before keygen
    mkdir -p "$CHROOT_PATH/home/openclaw/.ssh"
    # We use the host's ssh-keygen if available, or just use the one in the chroot
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys ssh-keygen -t ed25519 -f /home/openclaw/.ssh/id_ed25519 -N ""
    # Ensure strict permissions on the generated private key
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 600 /home/openclaw/.ssh/id_ed25519
    cp "$CHROOT_PATH/home/openclaw/.ssh/id_ed25519" /persist/ssh/id_ed25519
    cp "$CHROOT_PATH/home/openclaw/.ssh/id_ed25519.pub" /persist/ssh/id_ed25519.pub
    # Ensure the copy on the shared PVC also has strict permissions and correct ownership for the OpenClaw pod
    chown 1000:1000 /persist/ssh/id_ed25519 /persist/ssh/id_ed25519.pub
    chmod 600 /persist/ssh/id_ed25519
    chmod 644 /persist/ssh/id_ed25519.pub
fi

# Ensure authorized_keys is set up in the rootfs
mkdir -p "$CHROOT_PATH/home/openclaw/.ssh"
cat /persist/ssh/id_ed25519.pub > "$CHROOT_PATH/home/openclaw/.ssh/authorized_keys"
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chown -R openclaw:openclaw /home/openclaw
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 755 /home/openclaw
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 700 /home/openclaw/.ssh
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 600 /home/openclaw/.ssh/authorized_keys

# Check for sshd and install if missing
if [ ! -f "$CHROOT_PATH/usr/sbin/sshd" ]; then
    echo "sshd missing in rootfs. Attempting to install openssh-server..."
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts apt-get update
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts apt-get install -y openssh-server
    if [ ! -f "$CHROOT_PATH/usr/sbin/sshd" ]; then
        echo "Error: Failed to install openssh-server. /usr/sbin/sshd still missing."
        exit 1
    fi
fi

# Ensure sshd privilege separation user exists inside the rootfs
if ! $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys id sshd >/dev/null 2>&1; then
    echo "Creating sshd privilege separation user..."
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys useradd -r -d /run/sshd -s /usr/sbin/nologin sshd || true
fi

# Run sshd via PRoot
# We bind the host's /etc/ssh/sshd_config so we use our configured settings
# We use -0 to fake root so sshd can start and handle logins
echo "Starting sshd via PRoot on port 2222..."
exec $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts -b /etc/ssh/sshd_config:/etc/ssh/sshd_config /usr/sbin/sshd -D -e -p 2222
