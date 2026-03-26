#!/bin/bash
set -e
CHROOT_PATH="/persist/rootfs"
PROOT="/persist/proot"

# Install sshd if missing
if ! command -v sshd >/dev/null; then
    apt-get update
    apt-get install -y openssh-server curl
fi

# Ensure host-side user exists for SSHD
if ! getent group openclaw > /dev/null; then groupadd -g 1000 openclaw; fi
if ! getent passwd openclaw > /dev/null; then
    useradd -u 1000 -g 1000 -m -s /usr/local/bin/openclaw-shell openclaw
fi

# Manage runtime SSH key for authentication
mkdir -p /persist/ssh
if [ ! -f /persist/ssh/id_ed25519 ]; then
    echo "Generating new runtime SSH keypair..."
    ssh-keygen -t ed25519 -f /persist/ssh/id_ed25519 -N ""
    chown 1000:1000 /persist/ssh/id_ed25519 /persist/ssh/id_ed25519.pub
    chmod 600 /persist/ssh/id_ed25519
    chmod 644 /persist/ssh/id_ed25519.pub
fi

# Configure authorized keys in the host container
mkdir -p /home/openclaw/.ssh
cat /persist/ssh/id_ed25519.pub > /home/openclaw/.ssh/authorized_keys
chown -R 1000:1000 /home/openclaw/.ssh
chmod 700 /home/openclaw/.ssh
chmod 600 /home/openclaw/.ssh/authorized_keys

# Also put them in the rootfs for consistency
mkdir -p "$CHROOT_PATH/home/openclaw/.ssh"
cat /persist/ssh/id_ed25519.pub > "$CHROOT_PATH/home/openclaw/.ssh/authorized_keys"
chown -R 1000:1000 "$CHROOT_PATH/home/openclaw/.ssh"
chmod 700 "$CHROOT_PATH/home/openclaw/.ssh"
chmod 600 "$CHROOT_PATH/home/openclaw/.ssh/authorized_keys"

# Create the shell wrapper
cat <<EOF > /usr/local/bin/openclaw-shell
#!/bin/bash
# Pass through commands or start an interactive shell using proot
# We use -0 to simulate root inside the proot environment
if [ -n "\$SSH_ORIGINAL_COMMAND" ]; then
    exec $PROOT -0 -r $CHROOT_PATH -b /proc -b /dev -b /sys /bin/bash -c "\$SSH_ORIGINAL_COMMAND"
else
    exec $PROOT -0 -r $CHROOT_PATH -b /proc -b /dev -b /sys /bin/bash
fi
EOF
chmod +x /usr/local/bin/openclaw-shell

# Add to /etc/shells if not present
if ! grep -q "/usr/local/bin/openclaw-shell" /etc/shells; then
    echo "/usr/local/bin/openclaw-shell" >> /etc/shells
fi

# Generate host keys if they don't exist
ssh-keygen -A

# Run sshd
mkdir -p /run/sshd
echo "Starting sshd on port 2222..."
exec /usr/sbin/sshd -D -e -p 2222
