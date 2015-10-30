#!/bin/sh

repo="$(dirname "$(readlink -f "$0")")/repo"
package="$1"

repo-remove --sign --verify "${repo}/cubyte.db.tar.gz"    "$package"
repo-remove --sign --verify "${repo}/cubyte.files.tar.gz" "$package"
rm "${repo}/${package}-*.pkg.tar.*"

