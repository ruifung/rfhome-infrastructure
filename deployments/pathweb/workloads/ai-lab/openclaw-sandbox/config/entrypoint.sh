#!/bin/sh
set -e
CHROOT_PATH="/persist/rootfs"
PROOT="/persist/proot"
DROPBEAR_RSA_KEY="/persist/ssh/dropbear_rsa_host_key"
DROPBEAR_ECDSA_KEY="/persist/ssh/dropbear_ecdsa_host_key"
DROPBEAR_ED25519_KEY="/persist/ssh/dropbear_ed25519_host_key"

# Install Dropbear on the host container
if ! command -v dropbear >/dev/null; then
    echo "Installing Dropbear on host..."
    apt-get update
    apt-get install -y dropbear-bin
fi

# Ensure host-side user exists
if ! getent group openclaw > /dev/null; then groupadd -g 1000 openclaw; fi
if ! getent passwd openclaw > /dev/null; then
    # We use /bin/sh on host; Dropbear will force the wrapper via -c
    useradd -u 1000 -g 1000 -m -s /bin/sh openclaw
fi

# Ensure host keys directory exists on PVC
mkdir -p /persist/ssh

# Generate Dropbear host keys if they don't exist
# We use host's dropbearkey
generate_key() {
    type=$1
    file=$2
    if [ ! -f "$file" ]; then
        echo "Generating Dropbear $type host key..."
        dropbearkey -t "$type" -f "$file"
    fi
}

generate_key rsa "$DROPBEAR_RSA_KEY"
generate_key ecdsa "$DROPBEAR_ECDSA_KEY"
generate_key ed25519 "$DROPBEAR_ED25519_KEY"

# Manage runtime SSH client keypair (for openclaw agent to connect)
if [ ! -f /persist/ssh/id_ed25519 ]; then
    echo "Generating new runtime SSH client keypair..."
    mkdir -p "$CHROOT_PATH/home/openclaw/.ssh"
    # Generate in rootfs first (via proot to ensure perms)
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys ssh-keygen -t ed25519 -f /home/openclaw/.ssh/id_ed25519 -N ""
    $PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 600 /home/openclaw/.ssh/id_ed25519
    # Sync to shared PVC
    cp "$CHROOT_PATH/home/openclaw/.ssh/id_ed25519" /persist/ssh/id_ed25519
    cp "$CHROOT_PATH/home/openclaw/.ssh/id_ed25519.pub" /persist/ssh/id_ed25519.pub
    chown 1000:1000 /persist/ssh/id_ed25519 /persist/ssh/id_ed25519.pub
    chmod 600 /persist/ssh/id_ed25519
    chmod 644 /persist/ssh/id_ed25519.pub
fi

# Ensure authorized_keys is set up on the HOST for Dropbear to authenticate the user
mkdir -p /home/openclaw/.ssh
cat /persist/ssh/id_ed25519.pub > /home/openclaw/.ssh/authorized_keys
chown -R 1000:1000 /home/openclaw/.ssh
chmod 700 /home/openclaw/.ssh
chmod 600 /home/openclaw/.ssh/authorized_keys

# Also set up in rootfs for consistency/internal use
mkdir -p "$CHROOT_PATH/home/openclaw/.ssh"
cat /persist/ssh/id_ed25519.pub > "$CHROOT_PATH/home/openclaw/.ssh/authorized_keys"
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chown -R openclaw:openclaw /home/openclaw
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 700 /home/openclaw/.ssh
$PROOT -0 -r "$CHROOT_PATH" -b /proc -b /dev -b /sys chmod 600 /home/openclaw/.ssh/authorized_keys

# Create the PRoot wrapper script on the HOST
cat <<EOF > /usr/local/bin/proot-wrapper
#!/bin/sh
# This script is forced by Dropbear. It handles both interactive shells
# and direct command execution (via SSH_ORIGINAL_COMMAND).
if [ -n "\$SSH_ORIGINAL_COMMAND" ]; then
    exec $PROOT -0 -r $CHROOT_PATH -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts /bin/bash -c "\$SSH_ORIGINAL_COMMAND"
else
    exec $PROOT -0 -r $CHROOT_PATH -b /proc -b /dev -b /sys -b /etc/resolv.conf -b /etc/hosts /bin/bash
fi
EOF
chmod +x /usr/local/bin/proot-wrapper

# Run Dropbear natively on host
# -F: Foreground, -E: Log to stderr, -p: Port
# -c: Force command (our proot wrapper)
echo "Starting native Dropbear on port 2222 (forcing PRoot)..."
exec /usr/sbin/dropbear -F -E -p 2222 -c /usr/local/bin/proot-wrapper \
    -r "$DROPBEAR_RSA_KEY" \
    -r "$DROPBEAR_ECDSA_KEY" \
    -r "$DROPBEAR_ED25519_KEY"
