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
sed -i 's/return this\.manager?.hasFeatureEnabled(feature) ?? false;/return true;/' /patched/license.js
sed -i 's/return this\.isLicensed(feature);/if (feature === constants_1.LICENSE_FEATURES.SHOW_NON_PROD_BANNER) return false; return true;/' /patched/license.js
sed -i 's/return this.getUsersLimit() === constants_1.UNLIMITED_LICENSE_QUOTA;/return true;/' /patched/license.js
sed -i 's/if (!this.isLicensed())/if (false)/' /patched/license.js

# Apply Permission Patches
sed -i '/exports.GLOBAL_MEMBER_SCOPES = \[/a\    '\''user:create'\'',' /patched/global-scopes.ee.js
sed -i '/exports.GLOBAL_MEMBER_SCOPES = \[/a\    '\''user:changeRole'\'',' /patched/global-scopes.ee.js
sed -i '/exports.GLOBAL_CHAT_USER_SCOPES = \[/a\    '\''user:create'\'',' /patched/global-scopes.ee.js
sed -i '/exports.GLOBAL_CHAT_USER_SCOPES = \[/a\    '\''user:changeRole'\'',' /patched/global-scopes.ee.js

echo "n8n Enterprise Edition patches applied successfully."
