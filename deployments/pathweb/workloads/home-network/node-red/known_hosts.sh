#!/bin/bash

# Originally taken from the Flux project (https://github.com/fluxcd/flux/tree/master/docker) where is under an
# Apache-2.0 license

set -eu

known_hosts_file=${1}
known_hosts_file=${known_hosts_file:-/etc/ssh/ssh_known_hosts}
hosts="github.com gitlab.com bitbucket.org ssh.dev.azure.com vs-ssh.visualstudio.com"
hosts_2022="source.developers.google.com"

# The heredoc below was generated by constructing a known_hosts using
#
#     ssh-keyscan github.com gitlab.com bitbucket.org ssh.dev.azure.com vs-ssh.visualstudio.com > ./known_hosts
#
# then generating the sorted fingerprints with
#
#     ssh-keygen -l -f ./known_hosts | LC_ALL=C sort
#
# then checking against the published fingerprints from:
#  - github.com: https://help.github.com/articles/github-s-ssh-key-fingerprints/
#  - gitlab.com: https://docs.gitlab.com/ee/user/gitlab_com/#ssh-host-keys-fingerprints
#  - bitbucket.org: https://confluence.atlassian.com/bitbucket/ssh-keys-935365775.html
#  - ssh.dev.azure.com & vs-ssh.visualstudio.com: sign in, then go to User settings -> SSH Public Keys
#    (this is where the public key fingerprint is shown; it's not a setting)
#  - source.developers.google.com: https://cloud.google.com/source-repositories/docs/cloning-repositories

fingerprints=$(mktemp -t)
cleanup() {
    rm -f "$fingerprints"
}
trap cleanup EXIT

# make sure sorting is in the same locale as the heredoc
export LC_ALL=C

generate() {
    ssh-keyscan ${hosts} > ${known_hosts_file}
    ssh-keyscan -p 2022 ${hosts_2022} >> ${known_hosts_file}
    ssh-keyscan -p 222 forgejo.services.home.yrf.me >> ${known_hosts_file}
}

validate() {
ssh-keygen -l -f ${known_hosts_file} | sort > "$fingerprints"

diff - "$fingerprints" <<EOF
2048 SHA256:ROQFvPThGrW4RuWLoL9tq9I9zJ42fK4XywyRtbOz/EQ gitlab.com (RSA)
2048 SHA256:ohD8VZEXGWo6Ez8GSEJQ9WpafgLFsOfLOtGGQCQo6Og ssh.dev.azure.com (RSA)
2048 SHA256:ohD8VZEXGWo6Ez8GSEJQ9WpafgLFsOfLOtGGQCQo6Og vs-ssh.visualstudio.com (RSA)
256 SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU github.com (ED25519)
256 SHA256:AGvEpqYNMqsRNIviwyk4J4HM0lEylomDBKOWZsBn434 [source.developers.google.com]:2022 (ECDSA)
256 SHA256:FC73VB6C4OQLSCrjEayhMp9UMxS97caD/Yyi2bhW/J0 bitbucket.org (ECDSA)
256 SHA256:HbW3g8zUjNSksFbqTiUWPWg2Bq1x8xdGUrliXFzSnUw gitlab.com (ECDSA)
256 SHA256:dEV2pdh8++ejxZ0siI4JNN1tglW982TRe043XWQ5AtY [forgejo.services.home.yrf.me]:222 (ED25519)
256 SHA256:eUXGGm1YGsMAS7vkcx6JOJdOGHPem5gQp4taiCfCLB8 gitlab.com (ED25519)
256 SHA256:m8WJNCwmOYt0iNfh7KNSecRSPd4A57rcAx3yGICF7GA [forgejo.services.home.yrf.me]:222 (ECDSA)
256 SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM github.com (ECDSA)
256 SHA256:ybgmFkzwOSotHTHLJgHO0QN8L0xErw6vd0VhFA9m3SM bitbucket.org (ED25519)
3072 SHA256:46OSHA1Rmj8E8ERTC6xkNcmGOw9oFxYr0WF6zWW8l1E bitbucket.org (RSA)
3072 SHA256:sK4SXbC22YYkbIgkV+Axr6ENiu2yRq1kpOgfvXRPhhs [forgejo.services.home.yrf.me]:222 (RSA)
3072 SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s github.com (RSA)
EOF

}

retries=10
count=0
ok=false
wait=2
until ${ok}; do
    generate && validate && ok=true || ok=false
    count=$(($count + 1))
    if [[ ${count} -eq ${retries} ]]; then
        echo "ssh-keyscan failed, no more retries left"
        exit 1
    fi
    sleep ${wait}
done