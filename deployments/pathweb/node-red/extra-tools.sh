#!/bin/bash
cd $(dirname $0)
if [[ ! -f speedtest/speedtest-$SPEEDTEST_VERSION ]]; then
    rm -rf speedtest
    mkdir -p speedtest
    pushd speedtest
    curl https://install.speedtest.net/app/cli/ookla-speedtest-$SPEEDTEST_VERSION-linux-$(arch).tgz | tar xvz
    touch speedtest-$SPEEDTEST_VERSION
    popd
fi
