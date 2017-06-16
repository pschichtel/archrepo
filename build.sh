#!/bin/bash
set -x
packages=$(cat /packages.txt)

repo_root=/repo
repo_ext=.db.tar

repo_file="${repo_root}/${REPO}${repo_ext}"

if [[ ! -e "$repo_file" ]]
then

    if [[ "$(ls -1 "$repo_root" | wc -l)" -gt 0 ]]
    then
        repose --root="$repo_root" --pool="$repo_root" --compess --files "$REPO"
    else
        repo-add "$repo_file"
    fi

fi

trusted_keys=$(cat /trusted_keys.txt)
for key in ${trusted_keys[@]}
do
    gpg --recv-keys $key
    gpg --lsign-key $key
done

pacconf=/etc/pacman.conf
echo "[${REPO}]" | sudo tee -a $pacconf
echo "SigLevel = Optional TrustAll" | sudo tee -a $pacconf
echo "Server = file://${repo_root}" | sudo tee -a $pacconf

sudo pacman -Sy
aursync "--repo=${REPO}" --no-view --tar --no-confirm --update "${packages[@]}"

