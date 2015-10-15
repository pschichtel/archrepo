#!/bin/bash

here="$(dirname "$(readlink -f "$0")")"
repo="${here}/repo"
temp="${here}/temp"
key_id="$(cat "${here}/key")"
key_pass="$(cat "${here}/.passphrase")"

packagefile="${here}/packages.txt"
if [[ ! -z "${PACKAGE_LIST}" ]]
then
    packagefile="${PACKAGE_LIST}"
fi

if [[ -z "${PKGDEST}" ]]
then
    export PKGDEST="${repo}"
fi

if [[ -z "${SRCPKGDEST}" ]]
then
    export SRCPKGDEST="${repo}"
fi

if [[ -z "${BUILDDIR}" ]]
then
    export BUILDDIR="${here}/makepkg"
fi

if [[ -z "${GPG_PRESET_PASS}" ]]
then
    export GPG_PRESET_PASS="/usr/lib/gnupg/gpg-preset-passphrase"
fi

if [[ ! -d "${repo}" ]]
then
    mkdir "${repo}"
    chmod 755 "${repo}"
fi


killall -v gpg-agent
gpg-agent --allow-preset-passphrase --default-cache-ttl 86400 --homedir "${here}/.gnupg" --daemon
#keygrip="$(gpg --fingerprint "${key_id}" | grep -oiP '(\s+[a-f0-9]{4}){10}' | sed 's/ //g')"
keygrip="$(gpg --with-keygrip -k | grep "${key_id}" -A 1 | grep Keygrip | grep -oiP '[a-f0-9]+$')"
$GPG_PRESET_PASS --passphrase "$key_pass" --preset "${keygrip}"

echo "Keygrip: ${keygrip}"

build() {
    local package="$1"

    local aur_base="https://aur.archlinux.org"
    # Find the snapshot URL on the package page. This is necessary due to packages that actually build multiple *.pkg's
    local snapshot_path="$(wget -q -O- "${aur_base}/packages/${package}/" | grep -oP '/cgit/aur.git/snapshot/[^"]+')"
    local url="${aur_base}${snapshot_path}"
    if ! wget -q "${url}"
    then
        echo "Failed to download ${package} from ${url}, skipping..."
        return 1
    fi

    # Same here, find the single existing package and unzip it
    local package_file="$(ls -1)"
    tar xf "${package_file}" || return 2

    # And again, find the only folder that patches the package file
    local package_dir="$(ls -1 | grep -v "${package_file}")"

    # actually build the package
    local makepkg="makepkg --syncdeps --check --clean --cleanbuild --noconfirm --needed --asdeps --sign --key ${key_id} ${MAKEPKG_OPTS}"
    local was_built=0
    pushd "${package_dir}"
        $makepkg
        was_built=$?
    popd

    # if the package has been built successfully
    # add it to the repo and refresh all repositories
    if [[ $was_built -eq 0 ]]
    then
        # Update repo index
        pushd "${repo}"
        repo-add --new \
                 --sign \
                 --key ${key_id} \
                 --remove \
                 "${repo}/cubyte.db.tar.gz" ${repo}/*.pkg.tar.xz
        repo-add --new \
                 --sign \
                 --key ${key_id} \
                 --remove \
                 --files \
                 "${repo}/cubyte.files.tar.gz" ${repo}/*.pkg.tar.xz
        popd
        sudo pacman -Sy
    fi
}

for package in $(cat "$packagefile")
do
    if [[ -z "$package" ]]
    then
        continue
    fi

    if [[ -f "${BUILDDIR}" ]]
    then
        echo "The build dir exists, but it's a file!"
        exit 1
    fi

    if [[ -d "${BUILDDIR}" ]]
    then
        rm -Rf "${BUILDDIR}"
    fi

    rm -Rf "${temp}"
    mkdir "${temp}"
    pushd "${temp}"

        build "${package}"

    popd

    rm -Rf "$build"
done

# Remove the build dir
rm -Rf "${BUILDDIR}"

# Remove unused packages
sudo pacman -Rns --noconfirm $(pacman -Qtdq)


