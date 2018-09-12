#!/usr/bin/env bash
#
# This script generates semantic versioning tags for auto-tagging.
# It uses the last manual tag and counts the commits since then,
# as well as adding current commit hash.
#
# Syntax looks rather complex as we must also rely on very old git versions.
#

# Be picky
set -e
set -u
# But not too much
set +o pipefail


############################################################
# Global variables
############################################################

# Default tag if none exists yet
DEFAULT_TAG="v0.1.0"

# Git commit hash length
DEFAULT_HASH_LEN="7"

# Regex to find last manual tag. E.g.: v0.1.2
TAG_REGEX="v[0-9]+\.[0-9]+\.[0-9]+"


############################################################
# Functions
############################################################

# Get the commit line with the last manual tag (specified by defined TAG_REGEX).
# If no such tag exists, return the first commit ever created.
get_commit_line() {
	local tag_regex="${1}"
	local line=

	# Note: git log --decorate=full produces a line similar to this one:
	# commit 4e6c82beff6ab4175f4d378b6442c8269a87dd8f (tag: refs/tags/v1.0.0, refs/remotes/origin/master, refs/heads/master)

	# Commit line with last manual tag
	line="$( git log --decorate=full 2>/dev/null \
		| grep ^commit \
		| grep -E "tags/${tag_regex}(\)|[[:space:]]|,)" \
		| head -1 )"

	# First commit line ever created in git
	if [ -z "${line}" ]; then
		line="$( git log 2>/dev/null | grep -E '^commit[[:space:]]+[a-f0-9]+' | tail -1 )"
	fi

	echo "${line}"
}

# Extract the git tag from the provided git commit line.
# If no tag exists in that line, use the default tag.
extract_git_tag() {
	local commit_line="${1}"
	local tag_regex="${2}"
	local default_tag="${3}"
	local tag=

	tag="$( echo "${commit_line}" \
		| grep -Eo "tags/${tag_regex}(\)|[[:space:]]|,)" \
		| grep -Eo "${tag_regex}" \
		| head -1 )"

	if [ -z "${tag}" ]; then
		tag="${default_tag}"
	fi

	echo "${tag}"
}

# Extract the git commit from the provided git commit line.
# If the commit is not found, error out.
extract_git_com() {
	local commit_line="${1}"
	local commit=

	commit="$( echo "${commit_line}" | awk '{print $2}' )"

	if [ -z "${commit}" ]; then
		>&2 echo "Error, no commit hash found."
		exit 1
	fi
	echo "${commit}"
}

# Get number of commits from specific commit
# against the current git HEAD.
num_commits_against_head() {
	local commit="${1}"

	git rev-list --count ${commit}..HEAD
}

# Get the current commit in specified length
current_commit() {
	local commit_len="${1}"
	local commit=

	commit="$( git rev-parse HEAD )"
	commit="${commit:0:${commit_len}}"
	echo "${commit}"
}


############################################################
# Main Entrypoint
############################################################

if ! command -v git >/dev/null 2>&1; then
	>&2 echo "Error, 'git' binary is required."
	exit 1
fi

# Retrieve information
COMMIT_LINE="$( get_commit_line "${TAG_REGEX}" )"
GIT_TAG="$( extract_git_tag "${COMMIT_LINE}" "${TAG_REGEX}" "${DEFAULT_TAG}" )"
GIT_COM="$( extract_git_com "${COMMIT_LINE}" )"
DIFFERENCE="$( num_commits_against_head "${GIT_COM}" )"

# Build new git tag
if [ $DIFFERENCE = "0" ]; then
printf "%s\n" \
	"${GIT_TAG}"
else
printf "%s-%s-g%s\n" \
	"${GIT_TAG}" \
	"${DIFFERENCE}" \
	"$( current_commit "${DEFAULT_HASH_LEN}" )"
fi
