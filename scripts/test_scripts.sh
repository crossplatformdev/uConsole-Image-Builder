#!/bin/bash
#
# test_scripts.sh - Test script for validating uConsole image builder scripts
#
# This script performs validation tests without requiring root privileges
# or actually building images. For full integration tests, see CI workflows.
#

# Note: NOT using set -e because we want to run all tests even if some fail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================"
echo "uConsole Image Builder - Test Suite"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0
skipped=0

test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((passed++))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((failed++))
}

test_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    ((skipped++))
}

echo "1. Bash Syntax Validation"
echo "============================="

# Test all bash scripts
cd "$REPO_ROOT"
for script in scripts/*.sh; do
    # Skip the test script itself to avoid recursion
    if [[ "$script" == *"test_scripts.sh" ]]; then
        continue
    fi
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            test_pass "Syntax valid: $(basename $script)"
        else
            test_fail "Syntax error: $(basename $script)"
        fi
    fi
done

echo ""
echo "2. YAML Workflow Validation"
echo "============================="

# Test workflow files
cd "$REPO_ROOT"
for workflow in .github/workflows/*.yml .github/workflows/*.yaml; do
    if [ -f "$workflow" ]; then
        if python3 -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
            test_pass "Valid YAML: $(basename $workflow)"
        else
            test_fail "Invalid YAML: $(basename $workflow)"
        fi
    fi
done

echo ""
echo "3. Script Execution Tests"
echo "============================="

# Test that scripts can be sourced
cd "$REPO_ROOT"
if source scripts/common_mounts.sh 2>/dev/null; then
    test_pass "common_mounts.sh can be sourced"
else
    test_fail "common_mounts.sh cannot be sourced"
fi

# Test script error handling (should fail gracefully)
cd "$REPO_ROOT"
output=$(./scripts/install_clockworkpi_kernel.sh 2>&1 || true)
if echo "$output" | grep -q "ERROR: Rootfs mount directory required"; then
    test_pass "install_clockworkpi_kernel.sh shows proper error message"
else
    test_fail "install_clockworkpi_kernel.sh error message incorrect"
fi

# Test suite validation
cd "$REPO_ROOT"
output=$(SUITE=invalid ./scripts/generate_rpi_image.sh 2>&1 || true)
if echo "$output" | grep -q "ERROR: Invalid SUITE"; then
    test_pass "generate_rpi_image.sh validates suite correctly"
else
    test_fail "generate_rpi_image.sh validation incorrect"
fi

echo ""
echo "4. File Structure Tests"
echo "============================="

cd "$REPO_ROOT"

# Check required directories exist
if [ -d "rpi-image-gen" ]; then
    test_pass "rpi-image-gen submodule directory exists"
else
    test_fail "rpi-image-gen submodule directory missing"
fi

if [ -d "artifacts/kernel-debs" ]; then
    test_pass "artifacts/kernel-debs directory exists"
else
    test_fail "artifacts/kernel-debs directory missing"
fi

if [ -f "patches/ak-rex.patch" ]; then
    test_pass "patches/ak-rex.patch exists"
else
    test_fail "patches/ak-rex.patch missing"
fi

# Check documentation exists
if [ -f "scripts/rpi_image_gen/README.md" ]; then
    test_pass "rpi-image-gen documentation exists"
else
    test_fail "rpi-image-gen documentation missing"
fi

if [ -f "CHANGES.md" ]; then
    test_pass "CHANGES.md exists"
else
    test_fail "CHANGES.md missing"
fi

echo ""
echo "5. Git Submodule Tests"
echo "============================="

cd "$REPO_ROOT"

# Check submodule is configured
if git submodule status | grep -q "rpi-image-gen"; then
    test_pass "rpi-image-gen submodule is configured"
else
    test_fail "rpi-image-gen submodule not configured"
fi

# Check .gitmodules exists
if [ -f ".gitmodules" ]; then
    test_pass ".gitmodules file exists"
else
    test_fail ".gitmodules file missing"
fi

echo ""
echo "6. Script Permissions Tests"
echo "============================="

cd "$REPO_ROOT"

# Check scripts are executable
for script in scripts/*.sh; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        test_pass "Executable: $(basename $script)"
    elif [ -f "$script" ]; then
        test_fail "Not executable: $(basename $script)"
    fi
done

echo ""
echo "7. Environment Variable Tests"
echo "============================="

cd "$REPO_ROOT"

# Test that scripts respect environment variables (skip if requires root)
test_skip "generate_rpi_image.sh SUITE variable test (requires root to fully test)"

echo ""
echo "======================================"
echo "Test Summary"
echo "======================================"
echo -e "${GREEN}Passed:${NC} $passed"
echo -e "${RED}Failed:${NC} $failed"
echo -e "${YELLOW}Skipped:${NC} $skipped"
echo "Total: $((passed + failed + skipped))"
echo ""

if [ $failed -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
