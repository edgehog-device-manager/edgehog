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

# =============================================================================
# License Header Checker and Fixer
# =============================================================================
# This script verifies and updates copyright year headers in project files.
# It supports both inline headers and REUSE.toml-based coverage.
#
# Usage:
#   ./license.sh --check              # Check all changed files (CI mode)
#   ./license.sh --fix                # Fix all changed files
#   ./license.sh --check file1 file2  # Check specific files
#   ./license.sh --fix file1 file2    # Fix specific files
#   ./license.sh --base main          # Compare against a specific branch
#   ./license.sh --help               # Show help
# =============================================================================

set -euo pipefail

# -------------------------- CONSTANTS --------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
readonly REUSE_CONFIG="$PROJECT_ROOT/REUSE.toml"
readonly CURRENT_YEAR="$(date +%Y)"

# -------------------------- GLOBALS --------------------------
MODE="check"        # check | fix
BASE_REF=""         # Base branch/ref for comparison
declare -a FILES=() # Explicit file list

# Counters for summary
declare -i FILES_CHECKED=0
declare -i FILES_PASSED=0
declare -i FILES_FAILED=0
declare -i FILES_FIXED=0
declare -i FILES_SKIPPED=0

# Arrays for tracking results
declare -a FAILED_FILES=()
declare -a FIXED_FILES=()
declare -a SKIPPED_FILES=()

# -------------------------- UTILITIES --------------------------

# Print usage information
usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] [FILES...]

Options:
  --check         Check mode: verify copyright years (default)
  --fix           Fix mode: update copyright years automatically
  --base REF      Compare changes against REF (branch, tag, or commit)
  --help, -h      Show this help message

Examples:
  $SCRIPT_NAME --check                    # Check changed files
  $SCRIPT_NAME --fix                      # Fix changed files
  $SCRIPT_NAME --check --base main        # Check changes vs main branch
  $SCRIPT_NAME --fix src/file.ts          # Fix specific file

Exit Codes:
  0   All checks passed / fixes applied successfully
  1   One or more files failed the check
  2   Script error (invalid arguments, missing dependencies)

Output Format (--check mode, machine-readable):
  FAIL|<file>|expected:<year>|found:<year|missing>
  PASS|<file>
  SKIP|<file>|<reason>
EOF
}

# Log message to stderr (for human-readable output)
log() {
  echo "$*" >&2
}

# Print machine-readable result line to stdout
emit_result() {
  local status="$1"
  shift
  echo "${status}|$*"
}

# Check if a command exists
require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    log "ERROR: Required command '$cmd' not found"
    exit 2
  fi
}

# Trap handler for errors
on_error() {
  log "ERROR: Exit status $? at line $LINENO"
  log "Command: $BASH_COMMAND"
  exit 2
}

trap on_error ERR

# --------------------- ARGUMENT PARSING ---------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix)
        MODE="fix"
        shift
        ;;
      --check)
        MODE="check"
        shift
        ;;
      --base)
        if [[ -z "${2:-}" ]]; then
          log "ERROR: --base requires a reference argument"
          exit 2
        fi
        BASE_REF="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      -*)
        log "ERROR: Unknown option: $1"
        usage
        exit 2
        ;;
      *)
        FILES+=("$1")
        shift
        ;;
    esac
  done
}

# --------------------- FILE SELECTION ---------------------

# Get list of files to process based on context
get_files_to_process() {
  # If explicit files provided, use those
  if [[ ${#FILES[@]} -gt 0 ]]; then
    printf "%s\n" "${FILES[@]}"
    return
  fi

  # If base ref provided, compare against it
  if [[ -n "$BASE_REF" ]]; then

    git diff --name-only --diff-filter=AM "$BASE_REF"...HEAD 2>/dev/null || \
    git diff --name-only --diff-filter=AM "$BASE_REF" HEAD
    return
  fi

  # Default: staged + unstaged + untracked files

  {
    # Modified files (unstaged)
    git diff --name-only --diff-filter=AM
    # Modified files (staged)
    git diff --name-only --cached --diff-filter=AM
    # New untracked files
    git ls-files --others --exclude-standard
  } | sort -u
}

# Check if a file should be skipped entirely
should_skip_file() {
  local file="$1"
  local reason=""

  # Skip REUSE.toml itself
  if [[ "$file" == "REUSE.toml" ]]; then
    reason="REUSE.toml is self-referential"
  # Skip license files
  elif [[ "$file" == LICENSES/* ]]; then
    reason="License file"
  # Skip non-existent files (deleted)
  elif [[ ! -e "$PROJECT_ROOT/$file" ]]; then
    reason="File does not exist"
  fi

  if [[ -n "$reason" ]]; then
    echo "$reason"
    return 0
  fi
  return 1
}

# ------------------------ REUSE.toml HELPERS ------------------------

# Find matching pattern in REUSE.toml for a given file
get_matching_reuse_pattern() {
  local file="$1"

  [[ ! -f "$REUSE_CONFIG" ]] && return 1

  # Extract all path patterns from REUSE.toml
  local patterns
  patterns=$(grep "^path =" "$REUSE_CONFIG" \
    | sed -E 's/^path = [\[]?//;s/[\]]?$//;s/"//g;s/'"'"'//g;s/,/ /g')

  # Disable globbing temporarily for safe pattern matching
  set -f
  local matched=""
  for pattern in $patterns; do
    # Use bash's glob matching (pattern on right side is treated as glob)
    if [[ "$file" == $pattern ]]; then
      matched="$pattern"
      break
    fi
  done
  set +f

  [[ -n "$matched" ]] && echo "$matched"
}

# Extract the year(s) from REUSE.toml for a given pattern
get_reuse_year_for_pattern() {
  local pattern="$1"

  # Escape pattern for grep
  local escaped_pattern
  escaped_pattern=$(printf '%s\n' "$pattern" | sed 's/[][\.*^$/]/\\&/g')

  # Find the copyright line and extract year(s)
  local copyright_line
  copyright_line=$(grep -A10 "path = .*${escaped_pattern}" "$REUSE_CONFIG" 2>/dev/null \
    | grep "SPDX-FileCopyrightText" | head -1 || true)

  if [[ -z "$copyright_line" ]]; then
    echo "missing"
    return
  fi

  # Extract year or year range (e.g., "2024" or "2024-2026")
  local year_match
  year_match=$(echo "$copyright_line" | grep -oE '[0-9]{4}(-[0-9]{4})?' | tail -1 || true)

  if [[ -z "$year_match" ]]; then
    echo "missing"
  else
    echo "$year_match"
  fi
}

# Update year in REUSE.toml for a given pattern
update_reuse_toml_year() {
  local pattern="$1"

  local escaped_pattern
  escaped_pattern=$(printf '%s\n' "$pattern" | sed 's/[][\.*^$/]/\\&/g')

  # Update the year range in the matching section
  sed -i "/path = .*[\"']${escaped_pattern}[\"']/,/SPDX-FileCopyrightText/ {
    /SPDX-FileCopyrightText/ {
      s/\([0-9]\{4\}\)\(-[0-9]\{4\}\)\?/\1-$CURRENT_YEAR/
      s/$CURRENT_YEAR-$CURRENT_YEAR/$CURRENT_YEAR/
    }
  }" "$REUSE_CONFIG"
}

# ------------------------ INLINE HEADER HELPERS ------------------------

# Extract year from .license sidecar file
get_license_file_year() {
  local file="$1"
  local license_file="$PROJECT_ROOT/${file}.license"

  # Check if .license file exists
  if [[ ! -f "$license_file" ]]; then
    return 1
  fi

  # Look for copyright patterns in the license file
  local year_match
  year_match=$(grep -iE "(copyright|©|SPDX-FileCopyrightText)" "$license_file" 2>/dev/null \
    | grep -oE '[0-9]{4}(-[0-9]{4})?' \
    | tail -1 || true)

  if [[ -z "$year_match" ]]; then
    echo "missing"
  else
    echo "$year_match"
  fi
  return 0
}

# Extract year from inline file header
get_inline_header_year() {
  local file="$1"

  # Look for common copyright patterns in first 50 lines
  local year_match
  year_match=$(head -50 "$PROJECT_ROOT/$file" 2>/dev/null \
    | grep -iE "(copyright|©)" \
    | grep -oE '[0-9]{4}(-[0-9]{4})?' \
    | tail -1 || true)

  if [[ -z "$year_match" ]]; then
    echo "missing"
  else
    echo "$year_match"
  fi
}

# Check if year string contains current year
year_contains_current() {
  local year_str="$1"

  [[ "$year_str" == "missing" ]] && return 1

  # Handle single year or range (2024 or 2024-2026)
  if [[ "$year_str" =~ -([0-9]{4})$ ]]; then
    # Range format: check end year
    local end_year="${BASH_REMATCH[1]}"
    [[ "$end_year" == "$CURRENT_YEAR" ]]
  else
    # Single year
    [[ "$year_str" == "$CURRENT_YEAR" ]]
  fi
}

# ------------------------ CORE LOGIC ------------------------

update_reuse_toml() {
  local pattern="$1"

  echo "  -> Updating copyright year to $CURRENT_YEAR for pattern: [$pattern]"

  local escaped_pattern
  escaped_pattern=$(printf '%s\n' "$pattern" | sed 's/[][\.*^$/]/\\&/g')

  sed -i "/path = .*[\"']${escaped_pattern}[\"']/,/SPDX-FileCopyrightText/ {
    /SPDX-FileCopyrightText/ {
      s/\([0-9]\{4\}\)\(-[0-9]\{4\}\)\?/\1-$CURRENT_YEAR/
      s/$CURRENT_YEAR-$CURRENT_YEAR/$CURRENT_YEAR/
    }
  }" "$REUSE_CONFIG"
}

# Check a single file and report result
check_file() {
  local file="$1"

  # Count this file as checked
  ((++FILES_CHECKED))

  # Check if file should be skipped
  local skip_reason
  if skip_reason=$(should_skip_file "$file"); then
    emit_result "SKIP" "$file" "$skip_reason"
    SKIPPED_FILES+=("$file:$skip_reason")
    ((++FILES_SKIPPED))
    return 0
  fi

  # Check if covered by REUSE.toml
  local matched_pattern
  matched_pattern=$(get_matching_reuse_pattern "$file" || true)

  local found_year=""
  local source=""

  if [[ -n "$matched_pattern" ]]; then
    source="REUSE.toml"
    found_year=$(get_reuse_year_for_pattern "$matched_pattern")
  elif found_year=$(get_license_file_year "$file" 2>/dev/null); then
    source=".license"
  else
    source="inline"
    found_year=$(get_inline_header_year "$file")
  fi

  # Check if year is current
  if year_contains_current "$found_year"; then
    emit_result "PASS" "$file"
    ((++FILES_PASSED))
    return 0
  else
    emit_result "FAIL" "$file" "expected:$CURRENT_YEAR" "found:$found_year" "source:$source"
    FAILED_FILES+=("$file")
    ((++FILES_FAILED))
    return 1
  fi
}

# Fix a single file
fix_file() {
  local file="$1"

  # Count this file as checked
  ((++FILES_CHECKED))

  # Check if file should be skipped
  local skip_reason
  if skip_reason=$(should_skip_file "$file"); then
    emit_result "SKIP" "$file" "$skip_reason"
    SKIPPED_FILES+=("$file:$skip_reason")
    ((++FILES_SKIPPED))
    return 0
  fi

  # Check if covered by REUSE.toml
  local matched_pattern
  matched_pattern=$(get_matching_reuse_pattern "$file" || true)

  local found_year=""

  if [[ -n "$matched_pattern" ]]; then
    found_year=$(get_reuse_year_for_pattern "$matched_pattern")
    if year_contains_current "$found_year"; then
      emit_result "PASS" "$file"
      ((++FILES_PASSED))
      return 0
    fi
    update_reuse_toml "$matched_pattern"
    emit_result "FIXED" "$file" "source:REUSE.toml"
    FIXED_FILES+=("$file")
    ((++FILES_FIXED))
    return 0
  fi

  # Check .license file or inline header
  local source=""
  if found_year=$(get_license_file_year "$file" 2>/dev/null); then
    source=".license"
  else
    found_year=$(get_inline_header_year "$file")
    source="inline"
  fi

  if year_contains_current "$found_year"; then
    emit_result "PASS" "$file"
    ((++FILES_PASSED))
    return 0
  fi

  uv run reuse annotate \
    --copyright 'SECO Mind Srl' \
    --copyright-style string \
    --merge-copyrights \
    --license 'Apache-2.0' \
    --template apache \
    --skip-unrecognised \
    "$file"

  emit_result "FIXED" "$file" "source:$source"
  FIXED_FILES+=("$file")
  ((++FILES_FIXED))
}

# Print summary for check mode
print_check_summary() {
  echo ""
  log "═══════════════════════════════════════════════════════════"
  log "License Check Summary"
  log "═══════════════════════════════════════════════════════════"
  log "  Expected Year: $CURRENT_YEAR"
  log "  Files Checked: $FILES_CHECKED"
  log "  Passed:        $FILES_PASSED"
  log "  Failed:        $FILES_FAILED"
  log "  Skipped:       $FILES_SKIPPED"
  log "═══════════════════════════════════════════════════════════"

  if [[ $FILES_FAILED -gt 0 ]]; then
    log ""
    log "Failed files:"
    for f in "${FAILED_FILES[@]}"; do
      log "  - $f"
    done
    log ""
    log "Run '$SCRIPT_NAME --fix' to automatically update these files."
  fi
}

# Print summary for fix mode
print_fix_summary() {
  echo ""
  log "═══════════════════════════════════════════════════════════"
  log "License Fix Summary"
  log "═══════════════════════════════════════════════════════════"
  log "  Target Year:   $CURRENT_YEAR"
  log "  Files Checked: $FILES_CHECKED"
  log "  Already OK:    $FILES_PASSED"
  log "  Fixed:         $FILES_FIXED"
  log "  Skipped:       $FILES_SKIPPED"
  log "═══════════════════════════════════════════════════════════"

  if [[ ${#FIXED_FILES[@]} -gt 0 ]]; then
    log ""
    log "Modified files:"
    for f in "${FIXED_FILES[@]}"; do
      log "  ✓ $f"
    done
  fi

  if [[ ${#SKIPPED_FILES[@]} -gt 0 ]]; then
    log ""
    log "Skipped files:"
    for entry in "${SKIPPED_FILES[@]}"; do
      local f="${entry%%:*}"
      local reason="${entry#*:}"
      log "  - $f ($reason)"
    done
  fi
}

# ------------------------ MAIN EXECUTION ------------------------

main() {
  # Verify we're in a git repo
  require_cmd git

  cd "$PROJECT_ROOT" || exit 2

  parse_args "$@"

  # Collect files to process
  local files_list
  files_list=$(get_files_to_process)

  if [[ -z "$files_list" ]]; then
    log "No files to process."
    exit 0
  fi

  # Track overall success for check mode
  local check_failed=false

  # Process each file
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    if [[ "$MODE" == "check" ]]; then
      check_file "$file" || check_failed=true
    else
      fix_file "$file"
    fi
  done <<< "$files_list"

  # Print summary
  if [[ "$MODE" == "check" ]]; then
    print_check_summary
    if [[ "$check_failed" == true ]]; then
      exit 1
    fi
  else
    print_fix_summary
  fi

  log ""
  log "✅ License $MODE completed successfully"
  exit 0
}

# Run main function
main "$@"
