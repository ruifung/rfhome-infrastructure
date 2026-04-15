# n8n Patch Verification Script
# Usage: ./test-patch.ps1 -Image "n8nio/n8n:2.17.0"

param (
    [Parameter(Mandatory=$true)]
    [string]$Image
)

$ErrorActionPreference = "Stop"
$WorkDir = Get-Location
$TestEnv = Join-Path $WorkDir "test_patch_env"

Write-Host "Testing n8n patches against image: $Image" -ForegroundColor Cyan

# 1. Cleanup and Prepare
if (Test-Path $TestEnv) { Remove-Item -Recurse -Force $TestEnv }
New-Item -ItemType Directory -Path "$TestEnv/usr/local/lib/node_modules/n8n/dist" -Force | Out-Null
New-Item -ItemType Directory -Path "$TestEnv/usr/local/lib/node_modules/n8n/node_modules/.pnpm/@n8n+permissions@file+packages+@n8n+permissions/node_modules/@n8n/permissions/dist/roles/scopes/" -Force | Out-Null
New-Item -ItemType Directory -Path "$TestEnv/patched" -Force | Out-Null

# 2. Extract Files
Write-Host "Extracting source files from image..."
podman pull $Image
podman run --rm --entrypoint cat $Image /usr/local/lib/node_modules/n8n/dist/license.js > "$TestEnv/usr/local/lib/node_modules/n8n/dist/license.js"
podman run --rm --entrypoint cat $Image /usr/local/lib/node_modules/n8n/node_modules/.pnpm/@n8n+permissions@file+packages+@n8n+permissions/node_modules/@n8n/permissions/dist/roles/scopes/global-scopes.ee.js > "$TestEnv/usr/local/lib/node_modules/n8n/node_modules/.pnpm/@n8n+permissions@file+packages+@n8n+permissions/node_modules/@n8n/permissions/dist/roles/scopes/global-scopes.ee.js"

# 3. Run Patch Script in Alpine
Write-Host "Executing activate-ee.sh in test container..."
$VolumeSrc = $TestEnv.Replace('\', '/')
$ScriptSrc = (Join-Path $WorkDir "activate-ee.sh").Replace('\', '/')

podman run --rm `
  -v "$($VolumeSrc)/usr:/usr_test:Z" `
  -v "$($VolumeSrc)/patched:/patched:Z" `
  -v "$($ScriptSrc):/activate-ee.sh:ro,Z" `
  alpine:latest sh -c "cp /activate-ee.sh /test.sh && sed -i 's|/usr/local/lib|/usr_test/local/lib|g' /test.sh && sh /test.sh"

# 4. Verification
Write-Host "Verifying results..." -ForegroundColor Yellow
$LicensePath = "$TestEnv/patched/license.js"
$ScopesPath = "$TestEnv/patched/global-scopes.ee.js"

$Tests = @(
    @{ Name="Banner Suppression"; Pattern="if (feature === `"feat:showNonProdBanner`") return false; return true;" },
    @{ Name="Feature Unlock"; Pattern="return true;" },
    @{ Name="Enterprise Plan"; Pattern="if (feature === `"planName`") return `"Enterprise`"" },
    @{ Name="Quota Unlock"; Pattern="if (feature.startsWith(`"quota:`")) return -1;" }
)

$Failed = 0
foreach ($Test in $Tests) {
    if (Select-String -Path $LicensePath -Pattern $Test.Pattern -SimpleMatch) {
        Write-Host "PASS: $($Test.Name)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: $($Test.Name) (Pattern not found)" -ForegroundColor Red
        $Failed++
    }
}

# Check scopes
if (Select-String -Path $ScopesPath -Pattern "user:create" -Quiet) {
     Write-Host "PASS: Scope Injection" -ForegroundColor Green
} else {
     Write-Host "FAIL: Scope Injection" -ForegroundColor Red
     $Failed++
}

# Cleanup
Remove-Item -Recurse -Force $TestEnv

if ($Failed -eq 0) {
    Write-Host "`nSUCCESS: All patches verified!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nERROR: $Failed patches failed to verify." -ForegroundColor Red
    exit 1
}
