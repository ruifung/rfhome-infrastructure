#!/bin/bash
cd /data
function install_package_if_needed() {
    local pkg=${1:-Package required}
    local version=${2:-Version required}
    local installUrl=${3:-InstallURL}
    local installTarget="$pkg@$version"
    shift 2
    if [[ $installUrl == git+* ]]; then
        installTarget=$installUrl
        shift 1
    fi
    local i=$(node -p "require('$pkg/package.json').version" 2>/dev/null)
    [ "$i" == "$version" ] || npm "$@" install $installTarget
}
install_package_if_needed node-red-context-redis 0.0.1 git+https://github.com/node-red/node-red-context-redis
install_package_if_needed passport-openidconnect 0.1.1