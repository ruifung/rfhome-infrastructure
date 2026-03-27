#!/bin/sh
set -e
CHROOT_PATH="/persist/rootfs"
PROOT="/persist/proot"
DROPBEAR_DSS_KEY="/persist/ssh/dropbear_dss_host_key"
DROPBEAR_RSA_KEY="/persist/ssh/dropbear_rsa_host_key"
DROPBEAR_ECDSA_KEY="/persist/ssh/dropbear_ecdsa_host_key"
DROPBEAR_ED25519_KEY="/persist/ssh/dropbear_ed25519_host_key"

# Ensure host keys directory exists on PVC
mkdir -p /persist/ssh

# Generate Dropbear host keys inside PRoot if they don't exist
# Dropbear uses its own key format
generate_key() {
    type=$1
    file=$2
    if [ ! -f "$file" ]; then
        echo "Generating Dropbear $type host key..."
        $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys dropbearkey -t "$type" -f "$file"
    fi
}

generate_key rsa "$DROPBEAR_RSA_KEY"
generate_key ecdsa "$DROPBEAR_ECDSA_KEY"
generate_key ed25519 "$DROPBEAR_ED25519_KEY"

# Manage runtime SSH key for authentication (for the openclaw user to login)
# Note: openclaw pod connects to this sandbox
if [ ! -f /persist/ssh/id_ed25519 ]; then
    echo "Generating new runtime SSH client keypair..."
    mkdir -p "$CHROOT_PATH/home/openclaw/.ssh"
    # Generate standard OpenSSH format key for the client to use
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys ssh-keygen -t ed25519 -f /home/openclaw/.ssh/id_ed25519 -N ""
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 600 /home/openclaw/.ssh/id_ed25519
    cp "$CHROOT_PATH/home/openclaw/.ssh/id_ed25519" /persist/ssh/id_ed25519
    cp "$CHROOT_PATH/home/openclaw/.ssh/id_ed25519.pub" /persist/ssh/id_ed25519.pub
    chown 1000:1000 /persist/ssh/id_ed25519 /persist/ssh/id_ed25519.pub
    chmod 600 /persist/ssh/id_ed25519
    chmod 644 /persist/ssh/id_ed25519.pub
fi

# Ensure authorized_keys is set up in the rootfs (Dropbear uses standard format)
mkdir -p "$CHROOT_PATH/home/openclaw/.ssh"
cat /persist/ssh/id_ed25519.pub > "$CHROOT_PATH/home/openclaw/.ssh/authorized_keys"
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chown -R openclaw:openclaw /home/openclaw
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 755 /home/openclaw
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 700 /home/openclaw/.ssh
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 600 /home/openclaw/.ssh/authorized_keys

# Check for dropbear and install if missing (fallback)
if [ ! -f "$CHROOT_PATH/usr/sbin/dropbear" ]; then
    echo "dropbear missing in rootfs. Attempting to install..."
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts apt-get update
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts apt-get install -y dropbear-bin
fi

# Run Dropbear via PRoot
# -F: Foreground
# -E: Log to stderr
# -p: Port
# -R: Create hostkeys as required (but we prefer explicit keys on PVC)
# -a: Allow connections to forwarded ports from any host (not needed here but useful)
echo "Starting Dropbear via PRoot on port 2222..."
exec $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts \
    /usr/sbin/dropbear -F -E -p 2222 \
    -r "$DROPBEAR_RSA_KEY" \
    -r "$DROPBEAR_ECDSA_KEY" \
    -r "$DROPBEAR_ED25519_KEY"
