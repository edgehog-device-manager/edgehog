#!/usr/bin/env bash

# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "edgehog")"
readonly DOC_DIR="$PROJECT_ROOT/backend"

# Check if a command exists
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log "ERROR: Required command '$cmd' not found"
        exit 2
    fi
}

version_entry() {
    local version="$1"
    local v_number
    v_number=${version/v/}

    cat <<EOF
    {
        version: "$version",
        url: "https://docs.edgehog.io/$v_number",
    },
EOF
}

snapshot_entry() {
    cat <<EOF
    {
        version: "snapshot (unreleased)",
        url: "https://docs.edgehog.io/snapshot",
    },
EOF
}

main() {
    # Prerequisite: git, sed and awk
    require_cmd git
    require_cmd sed
    require_cmd awk

    # Move to doc directory
    cd "$DOC_DIR" || exit 2

    # collect git tags
    local git_tags

    # consider only git tags that adhere to semver. This way versions like
    # `v0.10.0-alpha.1` will not have official docs published
    git_tags=$(git tag -l --sort=-v:refname | sed 's/-.*$//g' | awk -F . '{ print $1"."$2 }' | awk '!NF || !seen[$0]++')

    out="var versionNodes = ["
    entry=$(snapshot_entry)
    out=$(printf "%s\n%s" "$out" "$entry")

    # for each tag
    for tag in $git_tags; do
        entry=$(version_entry "$tag")
        out=$(printf "%s\n%s" "$out" "$entry")
    done

    echo -ne "$out\n]\n"
}

main
