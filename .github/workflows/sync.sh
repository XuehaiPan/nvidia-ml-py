#!/usr/bin/env bash

# shellcheck disable=SC2292 # Other shells must be able to evaluate this guard.
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Bash is required to interpret this script." >&2
    exit 1
fi

set -euo pipefail

SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
cd -- "${SCRIPT_DIR}/../.."

PACKAGE_NAME="nvidia-ml-py"
PYPI_JSON_URL="${PYPI_JSON_URL:-"https://pypi.org/pypi/${PACKAGE_NAME}/json"}"
export GIT_AUTHOR_NAME="NVIDIA Corporation"
export GIT_AUTHOR_EMAIL="nvml-bindings@nvidia.com"
export GIT_COMMITTER_EMAIL="github-actions[bot]@users.noreply.github.com"
export GIT_COMMITTER_NAME="github-actions[bot]"

STATUS="$(git status --porcelain --untracked-files=all)"
if [[ -n "${STATUS}" ]]; then
    echo 'Commit or stash your local changes before synchronizing releases.' >&2
    exit 1
fi
git fetch --tags origin

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TEMP_DIR}"' EXIT

curl -fsSL --retry 32 "${PYPI_JSON_URL}" |
    jq -r '
        [.releases | to_entries[] | .key as $version | .value[] |
         select(.packagetype == "sdist" and (.yanked | not)) |
         {version: $version, parts: ($version | split(".") | map(tonumber)), file: .} |
         select(.parts[0] >= 10)] |
        sort_by(.parts)[] |
        [.version, .file.upload_time_iso_8601, .file.url, .file.digests.sha256] | @tsv
    ' >"${TEMP_DIR}/releases.tsv"

while IFS=$'\t' read -r version upload_time url sha256; do
    if git show-ref --verify --quiet "refs/tags/${version}"; then
        continue
    fi

    title="${PACKAGE_NAME} ${version}"
    project_url="https://pypi.org/project/${PACKAGE_NAME}/${version}"
    echo "Importing ${title} from ${url}"
    archive="${TEMP_DIR}/${version}.tar.gz"
    curl -fsSL --retry 32 --output "${archive}" "${url}"
    printf '%s  %s\n' "${sha256}" "${archive}" | sha256sum -c -
    source_dir="${TEMP_DIR}/${version}"
    mkdir -- "${source_dir}"
    # Some releases omit the license and ignore rules. Carry those forward as defaults.
    cp -- LICENSE .gitignore "${source_dir}/"
    tar -xzf "${archive}" -C "${source_dir}" --strip-components 1 --exclude '*.egg*'

    # Build the snapshot outside the checkout so Git can apply additions and deletions together.
    (
        export GIT_INDEX_FILE="${TEMP_DIR}/index"
        git read-tree HEAD
        git --work-tree="${source_dir}" add --all -- . ':!.github'
        git write-tree >"${TEMP_DIR}/tree"
    )
    read -r tree <"${TEMP_DIR}/tree"
    git read-tree -m -u HEAD "${tree}"
    GIT_AUTHOR_DATE="${upload_time}" git commit --allow-empty \
        -m "${title}" -m "${project_url}" \
        -m "Co-authored-by: Xuehai Pan <XuehaiPan@pku.edu.cn>"
    git tag -a "${version}" -m "${title}" -m "${project_url}"
done <"${TEMP_DIR}/releases.tsv"
