#!/usr/bin/env bash

set -euxo pipefail

REPO_DIR="$(dirname "$(dirname "$(cd "$(dirname "$0")" && pwd -P)")")"

cd "${REPO_DIR}" || exit 1

PACKAGE_NAME="nvidia-ml-py"
PYPI_JSON_URL="https://pypi.org/pypi/${PACKAGE_NAME}/json"
export GIT_AUTHOR_NAME="NVIDIA Corporation"
export GIT_AUTHOR_EMAIL="nvml-bindings@nvidia.com"
export GIT_COMMITTER_EMAIL="github-actions[bot]@users.noreply.github.com"
export GIT_COMMITTER_NAME="github-actions[bot]"

if [[ -n "$(git status --porcelain)" ]]; then
	echo "Working directory is not clean" >&2
	exit 1
fi
if [[ -n "$(git tag --list)" ]]; then
	git tag --delete $(git tag --list)
fi
git fetch --all --tags --force

curl -fsSL --retry 32 "${PYPI_JSON_URL}" |
	jq '.releases | to_entries[] | {version: .key} + (.value | flatten[]) |
		select(.packagetype == "sdist" and (.yanked | not)) |
		. + {version_tuple: .version | split(".") | map(tonumber)} |
		select(.version_tuple >= [10])' |
	jq -nr '[inputs] | sort_by(.version_tuple)[] |
			.version + ";" + .upload_time_iso_8601 + ";" + .url' |
	sort -V |
	while IFS=';' read -r version upload_time url; do
		printf "%-10s -- %s -- %s\n" "${version}" "${upload_time}" "${url}"
		if [[ -n "$(git tag --list "${version}")" ]]; then
			echo "Tag ${version} already exists"
			continue
		fi

		rm -rf "${REPO_DIR:?.}"/*
		git checkout HEAD -- LICENSE .gitignore .github

		curl -fsSL --retry 32 "${url}" | tar -xz --strip-components 1 --exclude '*.egg*'

		export GIT_AUTHOR_DATE="${upload_time}"
		git add --all
		git commit \
			-m "${PACKAGE_NAME} ${version}" \
			-m "https://pypi.org/project/${PACKAGE_NAME}/${version}" \
			-m "Co-authored-by: Xuehai Pan <XuehaiPan@pku.edu.cn>"
		git tag -a "${version}" \
			-m "${PACKAGE_NAME} ${version}" \
			-m "https://pypi.org/project/${PACKAGE_NAME}/${version}"
	done
