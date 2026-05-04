#!/bin/sh

set -eu

repo_full_name="${GITHUB_REPOSITORY:-Nheko-Reborn/nheko}"
github_api_url="${GITHUB_API_URL:-https://api.github.com}"
github_server_url="${GITHUB_SERVER_URL:-https://github.com}"
github_auth_token="${GITHUB_AUTH_TOKEN:-${GITHUB_TOKEN:-}}"
release_tag="${RELEASE_TAG:-${CI_COMMIT_TAG:-}}"
release_name="${RELEASE_NAME:-${release_tag}}"
release_target_commitish="${RELEASE_TARGET_COMMITISH:-${GITHUB_SHA:-master}}"
release_draft="${RELEASE_DRAFT:-true}"
release_prerelease="${RELEASE_PRERELEASE:-true}"
artifacts_dir="${ARTIFACTS_DIR:-./artifacts}"

if [ -z "${github_auth_token}" ]; then
    echo "GITHUB_AUTH_TOKEN or GITHUB_TOKEN is unset or empty; exiting"
    exit 1
fi

if [ -z "${release_tag}" ]; then
    echo "RELEASE_TAG or CI_COMMIT_TAG is unset or empty; exiting"
    exit 1
fi

if [ -z "${release_name}" ]; then
    echo "RELEASE_NAME resolved to an empty value; exiting"
    exit 1
fi

if [ ! -d "${artifacts_dir}" ]; then
    echo "Artifacts directory '${artifacts_dir}' does not exist; exiting"
    exit 1
fi

if [ -n "${RELEASE_BODY:-}" ]; then
    release_body="${RELEASE_BODY}"
elif [ -n "${CI_COMMIT_TAG:-}" ] && [ -f CHANGELOG.md ]; then
    echo "Release body not provided; deriving notes from CHANGELOG.md"
    release_body="$(perl -0777 -ne '/.*?(## .*?)\n(## |\Z)/s && print $1' CHANGELOG.md)"
else
    run_url="${github_server_url}/${repo_full_name}/actions/runs/${GITHUB_RUN_ID:-}"
    release_body="Automated build for ${release_name}

Commit: ${GITHUB_SHA:-unknown}
Workflow run: ${run_url}"
fi

releases_url="${github_api_url}/repos/${repo_full_name}/releases"
release_by_tag_url="${releases_url}/tags/${release_tag}"

echo "Checking if release exists for ${release_tag}"
http_code="$(curl \
    -sS \
    -o /dev/null \
    -I \
    -w "%{http_code}" \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${github_auth_token}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${release_by_tag_url}")"

if [ "${http_code}" = "404" ]; then
    echo "Creating release '${release_name}' for tag '${release_tag}'"
    create_payload="$(jq -n \
        --arg tag_name "${release_tag}" \
        --arg target_commitish "${release_target_commitish}" \
        --arg name "${release_name}" \
        --arg body "${release_body}" \
        --argjson draft "${release_draft}" \
        --argjson prerelease "${release_prerelease}" \
        '{tag_name: $tag_name, target_commitish: $target_commitish, name: $name, body: $body, draft: $draft, prerelease: $prerelease, generate_release_notes: false}')"
    release_json="$(curl \
        -sS \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${github_auth_token}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${releases_url}" \
        -d "${create_payload}")"
elif [ "${http_code}" = "200" ]; then
    echo "Release already exists for ${release_tag}; updating metadata"
    release_json="$(curl \
        -sS \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${github_auth_token}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${release_by_tag_url}")"
    release_id="$(printf '%s' "${release_json}" | jq -r '.id')"
    update_payload="$(jq -n \
        --arg target_commitish "${release_target_commitish}" \
        --arg name "${release_name}" \
        --arg body "${release_body}" \
        --argjson draft "${release_draft}" \
        --argjson prerelease "${release_prerelease}" \
        '{target_commitish: $target_commitish, name: $name, body: $body, draft: $draft, prerelease: $prerelease}')"
    release_json="$(curl \
        -sS \
        -X PATCH \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${github_auth_token}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${releases_url}/${release_id}" \
        -d "${update_payload}")"
else
    echo "Unexpected HTTP status while looking up release tag '${release_tag}': ${http_code}" >&2
    exit 1
fi

upload_url="$(printf '%s' "${release_json}" | jq -r '.upload_url' | sed 's/{?name,label\}/?name/g')"
echo "Using upload URL: ${upload_url}"

artifact_count=0
for file in "${artifacts_dir}"/*; do
    if [ ! -e "${file}" ]; then
        continue
    fi

    artifact_count=$((artifact_count + 1))
    name="${file##*/}"
    asset_id="$(printf '%s' "${release_json}" | jq -r --arg name "${name}" '.assets[]? | select(.name == $name) | .id' | sed -n '1p')"

    if [ -n "${asset_id}" ]; then
        echo "Deleting existing asset '${name}' from release"
        curl \
            -sS \
            -X DELETE \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${github_auth_token}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "${releases_url}/assets/${asset_id}" >/dev/null
    fi

    echo "Uploading ${file}"
    curl \
        -sS \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${github_auth_token}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/octet-stream" \
        "${upload_url}=${name}" \
        --data-binary "@${file}" >/dev/null
done

if [ "${artifact_count}" -eq 0 ]; then
    echo "No files found in '${artifacts_dir}' to upload; exiting"
    exit 1
fi
