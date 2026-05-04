#!/bin/sh
# Copy the original run script to the volume
cp /etc/s6-overlay/s6-rc.d/otbr-agent/run /patched/run
# Replace the hardcoded "::" with the POD_IP environment variable
# Line 125 in the source is otbr_rest_listen="::"
sed -i 's/otbr_rest_listen="::"/otbr_rest_listen="${POD_IP:-::}"/g' /patched/run
