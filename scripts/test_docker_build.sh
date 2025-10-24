#!/bin/bash
#
# test_docker_build.sh - Integration test for Docker-based kernel building
#
# This script tests the Docker build functionality without doing a full kernel build
# (which would take hours). Instead, it validates the Docker setup and scripts.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======================================"
echo "Docker Build Integration Test"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    exit 1
}

test_info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# Test 1: Check Docker is available
echo "1. Checking Docker availability..."
if command -v docker &> /dev/null; then
    test_pass "Docker command is available"
else
    test_fail "Docker is not installed or not in PATH"
fi

# Test 2: Check Docker daemon is running
echo ""
echo "2. Checking Docker daemon..."
if docker info &> /dev/null; then
    test_pass "Docker daemon is running"
else
    test_fail "Docker daemon is not running"
fi

# Test 3: Check Dockerfile exists
echo ""
echo "3. Checking Dockerfile..."
cd "$REPO_ROOT"
if [ -f "Dockerfile.kernel-builder" ]; then
    test_pass "Dockerfile.kernel-builder exists"
else
    test_fail "Dockerfile.kernel-builder not found"
fi

# Test 4: Build Docker image
echo ""
echo "4. Building Docker image..."
test_info "This may take a few minutes on first build..."
if docker build -t uconsole-kernel-builder-test -f Dockerfile.kernel-builder . > /tmp/docker-build.log 2>&1; then
    test_pass "Docker image built successfully"
else
    test_fail "Failed to build Docker image (see /tmp/docker-build.log)"
fi

# Test 5: Verify image exists
echo ""
echo "5. Verifying Docker image..."
if docker images uconsole-kernel-builder-test | grep -q uconsole-kernel-builder-test; then
    IMAGE_SIZE=$(docker images uconsole-kernel-builder-test --format "{{.Size}}")
    test_pass "Docker image exists (size: $IMAGE_SIZE)"
else
    test_fail "Docker image not found"
fi

# Test 6: Test container can run basic commands
echo ""
echo "6. Testing container execution..."
if docker run --rm uconsole-kernel-builder-test echo "test" > /tmp/docker-run.log 2>&1; then
    test_pass "Container can execute commands"
else
    test_fail "Container execution failed (see /tmp/docker-run.log)"
fi

# Test 7: Check required tools in container
echo ""
echo "7. Checking build tools in container..."
REQUIRED_TOOLS="make gcc git bc bison flex"
for tool in $REQUIRED_TOOLS; do
    if docker run --rm uconsole-kernel-builder-test which $tool > /dev/null 2>&1; then
        test_pass "Tool available in container: $tool"
    else
        test_fail "Tool missing in container: $tool"
    fi
done

# Test 8: Verify cross-compilation tools
echo ""
echo "8. Checking ARM64 cross-compilation tools..."
if docker run --rm uconsole-kernel-builder-test which aarch64-linux-gnu-gcc > /dev/null 2>&1; then
    test_pass "ARM64 cross-compiler available"
else
    test_fail "ARM64 cross-compiler not found"
fi

# Test 9: Test script mounting
echo ""
echo "9. Testing script volume mounting..."
TMP_OUTPUT="/tmp/test-kernel-output-$$"
mkdir -p "$TMP_OUTPUT"

if docker run --rm \
    -v "$SCRIPT_DIR/build_kernel_in_container.sh:/build/build_kernel_in_container.sh:ro" \
    -v "$TMP_OUTPUT:/output" \
    uconsole-kernel-builder-test \
    bash -n /build/build_kernel_in_container.sh > /dev/null 2>&1; then
    test_pass "Scripts can be mounted and validated in container"
else
    test_fail "Script mounting or validation failed"
fi

# Test 10: Test environment variable passing
echo ""
echo "10. Testing environment variable passing..."
TEST_VAR="test_value_$$"
RESULT=$(docker run --rm -e TEST_VAR="$TEST_VAR" uconsole-kernel-builder-test bash -c 'echo $TEST_VAR')
if [ "$RESULT" = "$TEST_VAR" ]; then
    test_pass "Environment variables passed correctly"
else
    test_fail "Environment variable passing failed"
fi

# Test 11: Verify wrapper script
echo ""
echo "11. Testing wrapper script functionality..."
if [ -x "$SCRIPT_DIR/build_kernel_docker.sh" ]; then
    test_pass "build_kernel_docker.sh is executable"
else
    test_fail "build_kernel_docker.sh is not executable"
fi

# Test 12: Test USE_DOCKER flag in main script
echo ""
echo "12. Testing USE_DOCKER integration..."
if bash -n "$SCRIPT_DIR/build_clockworkpi_kernel.sh"; then
    test_pass "build_clockworkpi_kernel.sh has valid syntax"
else
    test_fail "build_clockworkpi_kernel.sh has syntax errors"
fi

# Cleanup
echo ""
echo "13. Cleanup..."
rm -rf "$TMP_OUTPUT"
test_info "Temporary files cleaned up"

echo ""
echo "======================================"
echo "All Docker Build Tests Passed!"
echo "======================================"
echo ""
echo "To perform a full kernel build test, run:"
echo "  USE_DOCKER=true ./scripts/build_clockworkpi_kernel.sh /tmp/test-kernel"
echo ""
echo "Note: This will take 1-2 hours and requires significant disk space."
echo ""

exit 0
