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
    local pattern="$1"
    local file="$2"
    local replacement="$3"
    if ! grep -qE "$pattern" "$file"; then
        echo "ERROR: Pattern '$pattern' not found in $file"
        exit 1
    fi
    sed -i "s/$pattern/$replacement/" "$file"
}

# 1. Unlock all manager-based feature checks
apply_patch 'return this\.manager\?\.hasFeatureEnabled(feature) \?\? false;' /patched/license.js 'return true;'

# 2. Surgical isLicensed override: Return false for banner, true for everything else.
# We match the function signature and the opening brace, then inject our logic.
apply_patch 'isLicensed(feature) \{' /patched/license.js 'isLicensed(feature) { if (feature === "feat:showNonProdBanner") return false; return true;'

# 3. Unlock User limits
apply_patch 'return this\.getUsersLimit() === constants_1\.UNLIMITED_LICENSE_QUOTA;' /patched/license.js 'return true;'
apply_patch 'if (!this\.isLicensed())' /patched/license.js 'if (false)'

# Apply Permission Patches
# We replace the whole assignment line to be safe
apply_patch 'exports\.GLOBAL_MEMBER_SCOPES = \[' /patched/global-scopes.ee.js "exports.GLOBAL_MEMBER_SCOPES = [ 'user:create', 'user:changeRole',"
apply_patch 'exports\.GLOBAL_CHAT_USER_SCOPES = \[' /patched/global-scopes.ee.js "exports.GLOBAL_CHAT_USER_SCOPES = [ 'user:create', 'user:changeRole',"

echo "n8n Enterprise Edition patches applied successfully."
