#!/bin/sh
# Patches adapted from https://github.com/Wild-Open/n8n-entreprise-unlock

set -e

# File Paths
LICENSE_FILE="/usr/local/lib/node_modules/n8n/dist/license.js"
PERMISSIONS_FILE="/usr/local/lib/node_modules/n8n/node_modules/.pnpm/@n8n+permissions@file+packages+@n8n+permissions/node_modules/@n8n/permissions/dist/roles/scopes/global-scopes.ee.js"

# Copy files to patched directory
cp "$LICENSE_FILE" /patched/license.js
cp "$PERMISSIONS_FILE" /patched/global-scopes.ee.js

# Apply License Patches
apply_patch() {
    local literal_pattern="$1"
    local file="$2"
    local replacement="$3"

    # Find the line number using fixed-string grep
    local line_num=$(grep -nF "$literal_pattern" "$file" | cut -d: -f1 | head -n1)

    if [ -z "$line_num" ]; then
        echo "ERROR: Pattern '$literal_pattern' not found in $file"
        exit 1
    fi

    # Replace the entire line at line_num with the replacement
    # We use a temp file to be safe and compatible with all sed versions
    sed "${line_num}c\\$replacement" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

apply_patch 'return this.manager?.hasFeatureEnabled(feature) ?? false;' /patched/license.js '        return true;'
apply_patch 'isLicensed(feature) {' /patched/license.js '    isLicensed(feature) { if (feature === "feat:showNonProdBanner") return false; return true;'
apply_patch 'return this.getUsersLimit() === constants_1.UNLIMITED_LICENSE_QUOTA;' /patched/license.js '        return true;'
apply_patch "return this.getValue('planName') ?? 'Community';" /patched/license.js "        return 'Enterprise';"
apply_patch "return this.getValue(constants_1.LICENSE_QUOTAS.TEAM_PROJECT_LIMIT) ?? 0;" /patched/license.js "        return 100;"
apply_patch "return this.getValue(constants_1.LICENSE_QUOTAS.AI_CREDITS) ?? 0;" /patched/license.js "        return 1000000;"

# Apply Permission Patches
apply_patch 'exports.GLOBAL_MEMBER_SCOPES = [' /patched/global-scopes.ee.js "exports.GLOBAL_MEMBER_SCOPES = [ 'user:create', 'user:changeRole',"
apply_patch 'exports.GLOBAL_CHAT_USER_SCOPES = [' /patched/global-scopes.ee.js "exports.GLOBAL_CHAT_USER_SCOPES = [ 'user:create', 'user:changeRole',"

echo "n8n Enterprise Edition patches applied successfully."
