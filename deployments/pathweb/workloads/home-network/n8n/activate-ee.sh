#!/bin/sh
# Patches adapted from https://github.com/Wild-Open/n8n-entreprise-unlock

# We do NOT set -e here because we want to try all patches and report all failures
FAILED_PATCHES=0

# File Paths
LICENSE_FILE="/usr/local/lib/node_modules/n8n/dist/license.js"
PERMISSIONS_FILE="/usr/local/lib/node_modules/n8n/node_modules/.pnpm/@n8n+permissions@file+packages+@n8n+permissions/node_modules/@n8n/permissions/dist/roles/scopes/global-scopes.ee.js"

echo "Starting n8n Enterprise Edition patching..."

# Copy files to patched directory
echo "Preparing files in memory-backed storage..."
cp "$LICENSE_FILE" /patched/license.js || { echo "FAILED: Could not copy license.js"; exit 1; }
cp "$PERMISSIONS_FILE" /patched/global-scopes.ee.js || { echo "FAILED: Could not copy global-scopes.ee.js"; exit 1; }

# Apply License Patches
apply_patch() {
    local literal_pattern="$1"
    local file="$2"
    local replacement="$3"
    local description="$4"

    echo "Applying patch: $description"

    # Find the line number using fixed-string grep
    local line_num=$(grep -nF "$literal_pattern" "$file" | cut -d: -f1 | head -n1)

    if [ -z "$line_num" ]; then
        echo "FAILED: Pattern '$literal_pattern' not found in $file"
        FAILED_PATCHES=$((FAILED_PATCHES + 1))
        return 1
    fi

    # Replace the entire line at line_num with the replacement
    if sed "${line_num}c\\$replacement" "$file" > "$file.tmp" && mv "$file.tmp" "$file"; then
        echo "SUCCESS: $description"
        return 0
    else
        echo "FAILED: Error during sed replacement for $description"
        FAILED_PATCHES=$((FAILED_PATCHES + 1))
        return 1
    fi
}

apply_patch 'return this.manager?.hasFeatureEnabled(feature) ?? false;' /patched/license.js '        return true;' "Unlock manager features"
apply_patch 'isLicensed(feature) {' /patched/license.js '    isLicensed(feature) { if (feature === "feat:showNonProdBanner") return false; return true;' "isLicensed override (Banner suppression)"
apply_patch 'return this.getUsersLimit() === constants_1.UNLIMITED_LICENSE_QUOTA;' /patched/license.js '        return true;' "Unlock user limits"
apply_patch "return this.getValue('planName') ?? 'Community';" /patched/license.js "        return 'Enterprise';" "Patch plan name"
apply_patch "return this.getValue(constants_1.LICENSE_QUOTAS.TEAM_PROJECT_LIMIT) ?? 0;" /patched/license.js "        return 100;" "Unlock team projects"
apply_patch "return this.getValue(constants_1.LICENSE_QUOTAS.AI_CREDITS) ?? 0;" /patched/license.js "        return 1000000;" "Unlock AI credits"

# Apply Permission Patches
apply_patch 'exports.GLOBAL_MEMBER_SCOPES = [' /patched/global-scopes.ee.js "exports.GLOBAL_MEMBER_SCOPES = [ 'user:create', 'user:changeRole'," "Global Member Scopes"
apply_patch 'exports.GLOBAL_CHAT_USER_SCOPES = [' /patched/global-scopes.ee.js "exports.GLOBAL_CHAT_USER_SCOPES = [ 'user:create', 'user:changeRole'," "Global Chat User Scopes"

if [ $FAILED_PATCHES -gt 0 ]; then
    echo "CRITICAL: $FAILED_PATCHES patch(es) failed to apply."
    echo "Check the logs above for specific failures. The main container will not start."
    exit 1
fi

echo "All n8n Enterprise Edition patches applied successfully."
