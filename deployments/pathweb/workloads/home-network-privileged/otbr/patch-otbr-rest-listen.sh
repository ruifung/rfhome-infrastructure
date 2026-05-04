#!/bin/bash
TARGET="/etc/s6-overlay/s6-rc.d/otbr-agent/run"
if [ -f "$TARGET" ]; then
    sed -i 's/otbr_rest_listen="::"/otbr_rest_listen="${POD_IP:-::}"/' "$TARGET"
    echo "Patched $TARGET to use POD_IP"
else
    echo "Target $TARGET not found"
    exit 1
fi
