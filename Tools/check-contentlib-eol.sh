#!/usr/bin/env bash
# Checks every ContentLib patch file ships with CRLF endings.
#
# ContentLib splits a patch file into class path and JSON on the first CRLF. A
# file checked out with LF endings is read as one long class path, so the patch
# is dropped with a "double slash in a class path" error and the mod loads with
# a vanilla progression tree. Windows checkouts always produced CRLF here, which
# is why only the Linux package was affected.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
content_lib=$repo_root/ContentLib

if [[ ! -d $content_lib ]]; then
    echo "No ContentLib folder under $repo_root" >&2
    exit 1
fi

offenders=()
while IFS= read -r -d '' file; do
    if ! grep -q $'\r' "$file"; then
        offenders+=("${file#"$repo_root"/}")
    fi
done < <(find "$content_lib" -name '*.json' -print0)

if (( ${#offenders[@]} > 0 )); then
    echo "${#offenders[@]} ContentLib file(s) have LF endings and would be dropped by ContentLib:" >&2
    printf '  %s\n' "${offenders[@]}" >&2
    echo >&2
    echo "Fix with: find ContentLib -name '*.json' -print0 | xargs -0 sed -i 's/\\r*\$/\\r/'" >&2
    exit 1
fi

count=$(find "$content_lib" -name '*.json' | wc -l)
echo "All $count ContentLib patch files are CRLF"
