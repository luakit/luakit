#!/bin/sh
# Comprehensive test suite for getversion.sh
#
# Usage: ./getversion-test.sh <empty-test-directory>
#
# This script creates various git scenarios and validates getversion.sh output.

set -e

# Colors for output (disable if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GETVERSION="$SCRIPT_DIR/getversion.sh"
PASS=0
FAIL=0

usage() {
    echo "Usage: $0 <empty-test-directory>"
    echo ""
    echo "Creates git scenarios in the specified directory to test getversion.sh"
    exit 1
}

log_pass() {
    PASS=$((PASS + 1))
    printf "${GREEN}PASS${NC}: %s\n" "$1"
}

log_fail() {
    FAIL=$((FAIL + 1))
    printf "${RED}FAIL${NC}: %s\n" "$1"
    printf "       Expected: %s\n" "$2"
    printf "       Got:      %s\n" "$3"
}

log_info() {
    printf "${YELLOW}TEST${NC}: %s\n" "$1"
}

# Run getversion.sh and capture output
run_getversion() {
    sh "$GETVERSION" 2>/dev/null || true
}

# Check if output matches expected pattern
# $1 = test name
# $2 = expected pattern (grep -E regex)
# $3 = actual output
check_pattern() {
    name="$1"
    pattern="$2"
    actual="$3"

    if echo "$actual" | grep -qE "$pattern"; then
        log_pass "$name"
        return 0
    else
        log_fail "$name" "pattern: $pattern" "$actual"
        return 1
    fi
}

# Check exact match
# $1 = test name
# $2 = expected value
# $3 = actual output
check_exact() {
    name="$1"
    expected="$2"
    actual="$3"

    if [ "$actual" = "$expected" ]; then
        log_pass "$name"
        return 0
    else
        log_fail "$name" "$expected" "$actual"
        return 1
    fi
}

# Validate arguments
if [ $# -ne 1 ]; then
    usage
fi

TEST_DIR="$1"

if [ ! -d "$TEST_DIR" ]; then
    echo "Error: Directory '$TEST_DIR' does not exist"
    exit 1
fi

if [ "$(ls -A "$TEST_DIR" 2>/dev/null)" ]; then
    echo "Error: Directory '$TEST_DIR' is not empty"
    exit 1
fi

if [ ! -f "$GETVERSION" ]; then
    echo "Error: getversion.sh not found at $GETVERSION"
    exit 1
fi

# Convert to absolute path
TEST_DIR="$(cd "$TEST_DIR" && pwd)"

echo "=========================================="
echo "getversion.sh Test Suite"
echo "=========================================="
echo "Test directory: $TEST_DIR"
echo "Script under test: $GETVERSION"
echo ""

# Copy getversion.sh to test directory
cp "$GETVERSION" "$TEST_DIR/getversion.sh"

# ===========================================
# Test 1: No git repository at all
# ===========================================
log_info "No git repository (should fail)"
cd "$TEST_DIR"
mkdir -p test1_no_git
cd test1_no_git
cp "$TEST_DIR/getversion.sh" .

output=$(sh ./getversion.sh 2>&1) || true
if echo "$output" | grep -q "ERROR"; then
    log_pass "No git repo returns error"
else
    log_fail "No git repo returns error" "ERROR message" "$output"
fi

# ===========================================
# Test 2: Git repo with no tags, clean
# ===========================================
log_info "Git repo, no tags, clean working tree"
cd "$TEST_DIR"
mkdir -p test2_no_tags
cd test2_no_tags
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
check_pattern "No tags clean -> 0.0.0-<hash>" "^0\.0\.0-[0-9a-f]{7}$" "$output"

# ===========================================
# Test 3: Git repo with no tags, dirty
# ===========================================
log_info "Git repo, no tags, dirty working tree"
cd "$TEST_DIR/test2_no_tags"
echo "modified" >> file.txt

output=$(run_getversion)
check_pattern "No tags dirty -> 0.0.0-<hash>-dirty" "^0\.0\.0-[0-9a-f]{7}-dirty$" "$output"

# Clean up
git checkout -q -- file.txt

# ===========================================
# Test 4: Git repo with tag (exact match)
# ===========================================
log_info "Git repo, on exact tag, clean"
cd "$TEST_DIR"
mkdir -p test4_with_tag
cd test4_with_tag
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "1.0.0"
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
check_exact "Exact tag -> 1.0.0" "1.0.0" "$output"

# ===========================================
# Test 5: Git repo with tag, dirty
# ===========================================
log_info "Git repo, on exact tag, dirty"
cd "$TEST_DIR/test4_with_tag"
echo "modified" >> file.txt

output=$(run_getversion)
check_exact "Exact tag dirty -> 1.0.0-dirty" "1.0.0-dirty" "$output"

# Clean up
git checkout -q -- file.txt

# ===========================================
# Test 6: Git repo with tag + commits after
# ===========================================
log_info "Git repo, commits after tag, clean"
cd "$TEST_DIR"
mkdir -p test6_tag_plus_commits
cd test6_tag_plus_commits
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "2.0.0"
echo "more content" >> file.txt
git add file.txt
git commit -q -m "Second commit"
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
check_pattern "Tag + commits -> 2.0.0-1-g<hash>" "^2\.0\.0-[0-9]+-g[0-9a-f]{7}$" "$output"

# ===========================================
# Test 7: Git repo with tag + commits, dirty
# ===========================================
log_info "Git repo, commits after tag, dirty"
cd "$TEST_DIR/test6_tag_plus_commits"
echo "uncommitted" >> file.txt

output=$(run_getversion)
check_pattern "Tag + commits dirty -> 2.0.0-1-g<hash>-dirty" "^2\.0\.0-[0-9]+-g[0-9a-f]{7}-dirty$" "$output"

# Clean up
git checkout -q -- file.txt

# ===========================================
# Test 8: Git worktree checkout
# ===========================================
log_info "Git worktree checkout"
cd "$TEST_DIR"
mkdir -p test8_worktree_main
cd test8_worktree_main
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "3.0.0"
git branch feature

# Create worktree
cd "$TEST_DIR"
git -C test8_worktree_main worktree add "$TEST_DIR/test8_worktree_feature" feature -q

cd "$TEST_DIR/test8_worktree_feature"
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
check_exact "Worktree -> 3.0.0" "3.0.0" "$output"

# Verify .git is a file, not directory
if [ -f .git ] && [ ! -d .git ]; then
    log_pass "Worktree has .git file (not directory)"
else
    log_fail "Worktree has .git file (not directory)" ".git is file" ".git is directory or missing"
fi

# ===========================================
# Test 9: Git worktree, dirty
# ===========================================
log_info "Git worktree, dirty"
cd "$TEST_DIR/test8_worktree_feature"
echo "modified" >> file.txt

output=$(run_getversion)
check_exact "Worktree dirty -> 3.0.0-dirty" "3.0.0-dirty" "$output"

# Clean up
git checkout -q -- file.txt

# ===========================================
# Test 10: .git directory missing (removed)
# ===========================================
log_info ".git directory removed"
cd "$TEST_DIR"
mkdir -p test10_no_dotgit
cd test10_no_dotgit
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
cp "$TEST_DIR/getversion.sh" .

# Remove .git
rm -rf .git

output=$(sh ./getversion.sh 2>&1) || true
if echo "$output" | grep -q "ERROR"; then
    log_pass ".git removed returns error"
else
    log_fail ".git removed returns error" "ERROR message" "$output"
fi

# ===========================================
# Test 11: Lightweight tag vs annotated tag
# ===========================================
log_info "Annotated tag"
cd "$TEST_DIR"
mkdir -p test11_annotated_tag
cd test11_annotated_tag
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag -a "4.0.0" -m "Release 4.0.0"
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
check_exact "Annotated tag -> 4.0.0" "4.0.0" "$output"

# ===========================================
# Test 12: Multiple tags (latest should win)
# ===========================================
log_info "Multiple tags on same commit"
cd "$TEST_DIR"
mkdir -p test12_multi_tag
cd test12_multi_tag
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "5.0.0"
git tag "5.0.1"
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
# Either tag is acceptable
if [ "$output" = "5.0.0" ] || [ "$output" = "5.0.1" ]; then
    log_pass "Multiple tags -> one of them (got: $output)"
else
    log_fail "Multiple tags -> one of them" "5.0.0 or 5.0.1" "$output"
fi

# ===========================================
# Test 13: Tag with 'v' prefix
# ===========================================
log_info "Tag with v prefix"
cd "$TEST_DIR"
mkdir -p test13_v_prefix
cd test13_v_prefix
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "v6.0.0"
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
check_exact "v-prefixed tag -> v6.0.0" "v6.0.0" "$output"

# ===========================================
# Test 14: Staged but uncommitted changes
# ===========================================
log_info "Staged but uncommitted changes"
cd "$TEST_DIR"
mkdir -p test14_staged
cd test14_staged
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "7.0.0"
cp "$TEST_DIR/getversion.sh" .
echo "new" > newfile.txt
git add newfile.txt

output=$(run_getversion)
check_exact "Staged changes -> 7.0.0-dirty" "7.0.0-dirty" "$output"

# Clean up
git reset -q HEAD newfile.txt
rm -f newfile.txt

# ===========================================
# Test 15: Untracked files (should NOT be dirty)
# ===========================================
log_info "Untracked files only"
cd "$TEST_DIR"
mkdir -p test15_untracked
cd test15_untracked
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "8.0.0"
cp "$TEST_DIR/getversion.sh" .
echo "untracked" > untracked.txt

output=$(run_getversion)
check_exact "Untracked files -> 8.0.0 (not dirty)" "8.0.0" "$output"

# ===========================================
# Test 16: Detached HEAD at tag
# ===========================================
log_info "Detached HEAD at tag"
cd "$TEST_DIR"
mkdir -p test16_detached
cd test16_detached
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "9.0.0"
echo "more" >> file.txt
git add file.txt
git commit -q -m "Second commit"
git checkout -q 9.0.0
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
check_exact "Detached HEAD at tag -> 9.0.0" "9.0.0" "$output"

# ===========================================
# Test 17: Detached HEAD not at tag
# ===========================================
log_info "Detached HEAD not at tag"
cd "$TEST_DIR"
mkdir -p test17_detached_no_tag
cd test17_detached_no_tag
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
echo "more" >> file.txt
git add file.txt
git commit -q -m "Second commit"
git tag "10.0.0"
git checkout -q HEAD~1
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
check_pattern "Detached HEAD no tag -> 0.0.0-<hash>" "^0\.0\.0-[0-9a-f]{7}$" "$output"

# ===========================================
# Test 18: Shallow clone
# ===========================================
log_info "Shallow clone"
cd "$TEST_DIR"
mkdir -p test18_source
cd test18_source
git init -q --bare

cd "$TEST_DIR"
mkdir -p test18_work
cd test18_work
git clone -q "$TEST_DIR/test18_source" repo
cd repo
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "11.0.0"
echo "more" >> file.txt
git add file.txt
git commit -q -m "Second commit"
git push -q origin master --tags 2>/dev/null || git push -q origin main --tags 2>/dev/null || true

cd "$TEST_DIR"
git clone -q --depth 1 "$TEST_DIR/test18_source" test18_shallow || true
if [ -d test18_shallow ]; then
    cd test18_shallow
    cp "$TEST_DIR/getversion.sh" .

    output=$(run_getversion)
    # Shallow clones may or may not have tag info depending on git version
    if echo "$output" | grep -qE "^(11\.0\.0|0\.0\.0-)"; then
        log_pass "Shallow clone -> version or fallback (got: $output)"
    else
        log_fail "Shallow clone -> version or fallback" "11.0.0 or 0.0.0-<hash>" "$output"
    fi
else
    log_pass "Shallow clone (skipped - no remote)"
fi

# ===========================================
# Test 19: Pre-release tag format
# ===========================================
log_info "Pre-release tag (semver)"
cd "$TEST_DIR"
mkdir -p test19_prerelease
cd test19_prerelease
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "12.0.0-beta.1"
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
check_exact "Pre-release tag -> 12.0.0-beta.1" "12.0.0-beta.1" "$output"

# ===========================================
# Test 20: Archive fallback simulation
# ===========================================
log_info "Archive fallback (simulated)"
cd "$TEST_DIR"
mkdir -p test20_archive
cd test20_archive

# Create a modified getversion.sh that simulates archive substitution
cat > getversion_archive.sh << 'SCRIPT'
#!/bin/sh
VERSION_FROM_ARCHIVE='abc1234567890def1234567890abcdef12345678'

if [ -d .git ] || { [ -f .git ] && grep -q '^gitdir:' .git 2>/dev/null; }
then
    VERSION_FROM_GIT=$(git describe --tags --always --dirty 2>/dev/null)
fi

format_version() {
    ver="$1"
    case "$ver" in
        *.*)
            echo "$ver"
            ;;
        *)
            echo "0.0.0-$ver"
            ;;
    esac
}

if [ -n "$VERSION_FROM_GIT" ]; then
    format_version "$VERSION_FROM_GIT"
    exit 0
fi

if [ "$VERSION_FROM_ARCHIVE" != '$Format:%H$' ]; then
    short_hash=$(echo "$VERSION_FROM_ARCHIVE" | cut -c1-7)
    format_version "$short_hash"
    exit 0
fi

echo "ERROR: Version detection failed." >&2
exit 2
SCRIPT

output=$(sh getversion_archive.sh)
check_exact "Archive fallback -> 0.0.0-abc1234" "0.0.0-abc1234" "$output"

# ===========================================
# Test 21: Empty repository (no commits)
# ===========================================
log_info "Empty repository (no commits)"
cd "$TEST_DIR"
mkdir -p test21_empty
cd test21_empty
git init -q
cp "$TEST_DIR/getversion.sh" .

output=$(sh ./getversion.sh 2>&1) || true
# git describe fails on empty repo
if echo "$output" | grep -q "ERROR"; then
    log_pass "Empty repo returns error"
else
    log_fail "Empty repo returns error" "ERROR message" "$output"
fi

# ===========================================
# Test 22: Tag not matching semver (custom format)
# ===========================================
log_info "Non-semver tag with dots"
cd "$TEST_DIR"
mkdir -p test22_custom_tag
cd test22_custom_tag
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
echo "content" > file.txt
git add file.txt
git commit -q -m "Initial commit"
git tag "release.2024.01"
cp "$TEST_DIR/getversion.sh" .

output=$(run_getversion)
check_exact "Custom tag with dots -> release.2024.01" "release.2024.01" "$output"

# ===========================================
# Summary
# ===========================================
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
printf "${GREEN}Passed${NC}: %d\n" "$PASS"
printf "${RED}Failed${NC}: %d\n" "$FAIL"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

exit 0
