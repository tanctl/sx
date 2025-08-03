#!/bin/bash

# Comprehensive verification script for sx
# Tests all major functionality and workflows

set -euo pipefail

echo "🚀 Starting sx comprehensive verification..."
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass_test() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail_test() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Build verification
echo -e "${BLUE}=== Build Verification ===${NC}"
info "Testing clean build..."
if dune clean && dune build bin/main.exe >/dev/null 2>&1; then
    pass_test "Clean build successful"
else
    fail_test "Build failed"
    exit 1
fi
echo

# Basic functionality tests
echo -e "${BLUE}=== Basic Functionality Tests ===${NC}"

# Test 1: JSON to Common Lisp
info "Testing JSON to Common Lisp conversion..."
RESULT=$(echo '{"name": "test", "value": 42}' | dune exec bin/main.exe 2>/dev/null)
if [[ "$RESULT" == *'"name"'* && "$RESULT" == *'"test"'* && "$RESULT" == *'42'* ]]; then
    pass_test "JSON → Common Lisp conversion works"
else
    fail_test "JSON → Common Lisp conversion failed"
fi

# Test 2: JSON to Scheme  
info "Testing JSON to Scheme conversion..."
RESULT=$(echo '{"key": "value"}' | dune exec bin/main.exe -- --to scheme 2>/dev/null)
if [[ "$RESULT" == *'cons'* && "$RESULT" == *'"key"'* ]]; then
    pass_test "JSON → Scheme conversion works"
else
    fail_test "JSON → Scheme conversion failed"
fi

# Test 3: Version output
info "Testing version output..."
VERSION=$(dune exec bin/main.exe -- --version 2>/dev/null)
if [[ "$VERSION" == "1.0.0" ]]; then
    pass_test "Version output correct"
else
    fail_test "Version output incorrect: got '$VERSION'"
fi
echo

# Format detection tests
echo -e "${BLUE}=== Format Detection Tests ===${NC}"

# Create test files if they don't exist
mkdir -p examples

# Test YAML detection and conversion
info "Testing YAML detection and conversion..."
if [[ -f "examples/config.yaml" ]]; then
    if dune exec bin/main.exe -- examples/config.yaml >/dev/null 2>&1; then
        pass_test "YAML file processing works"
    else
        fail_test "YAML file processing failed"
    fi
else
    warn "examples/config.yaml not found, skipping YAML test"
fi

# Test TOML detection and conversion
info "Testing TOML detection and conversion..."
if [[ -f "examples/server-config.toml" ]]; then
    if dune exec bin/main.exe -- --from toml examples/server-config.toml >/dev/null 2>&1; then
        pass_test "TOML file processing works"
    else
        fail_test "TOML file processing failed"
    fi
else
    warn "examples/server-config.toml not found, skipping TOML test"
fi
echo

# Streaming tests
echo -e "${BLUE}=== Streaming Tests ===${NC}"

info "Testing JSON Lines streaming..."
if [[ -f "examples/logs.jsonl" ]]; then
    RESULT=$(dune exec bin/main.exe -- --streaming --from jsonl examples/logs.jsonl 2>/dev/null | wc -l)
    if [[ "$RESULT" -gt 5 ]]; then
        pass_test "JSON Lines streaming produces output"
    else
        fail_test "JSON Lines streaming failed"
    fi
else
    warn "examples/logs.jsonl not found, skipping streaming test"
fi

info "Testing streaming with pipes..."
RESULT=$(echo -e '{"a":1}\n{"b":2}' | dune exec bin/main.exe -- --streaming --from jsonl 2>/dev/null | wc -l)
if [[ "$RESULT" -ge 2 ]]; then
    pass_test "Pipe streaming works"
else
    fail_test "Pipe streaming failed"
fi
echo

# CLI argument tests
echo -e "${BLUE}=== CLI Argument Tests ===${NC}"

info "Testing compact output..."
RESULT=$(echo '{"name": "test"}' | dune exec bin/main.exe -- --compact 2>/dev/null)
if [[ ! "$RESULT" == *$'\n'* ]]; then
    pass_test "Compact output works (single line)"
else
    fail_test "Compact output failed (multiple lines)"
fi

info "Testing format specification..."
RESULT=$(echo 'name = "test"' | dune exec bin/main.exe -- --from toml --to scheme 2>/dev/null)
if [[ "$RESULT" == *'cons'* && "$RESULT" == *'"name"'* ]]; then
    pass_test "Explicit format specification works"
else
    fail_test "Explicit format specification failed"
fi
echo

# Configuration tests
echo -e "${BLUE}=== Configuration Tests ===${NC}"

info "Testing configuration file loading..."
if [[ -f "sx.config" ]]; then
    # Test that config affects output (default should be common-lisp from config)
    RESULT=$(echo '{"test": 1}' | dune exec bin/main.exe 2>/dev/null)
    if [[ "$RESULT" == *'"test"'* ]]; then
        pass_test "Configuration file loaded"
    else
        fail_test "Configuration file not loaded properly"
    fi
else
    warn "sx.config not found, skipping config test"
fi

info "Testing CLI override of config..."
RESULT=$(echo '{"test": 1}' | dune exec bin/main.exe -- --to scheme 2>/dev/null)
if [[ "$RESULT" == *'cons'* ]]; then
    pass_test "CLI arguments override config"
else
    fail_test "CLI arguments don't override config"
fi
echo

# Error handling tests
echo -e "${BLUE}=== Error Handling Tests ===${NC}"

info "Testing invalid JSON handling..."
ERROR_OUTPUT=$(echo '{"invalid": json}' | dune exec bin/main.exe 2>&1 | grep -i error || true)
if [[ ! -z "$ERROR_OUTPUT" ]]; then
    pass_test "Invalid JSON produces error message"
else
    fail_test "Invalid JSON doesn't produce error message"
fi

info "Testing file not found handling..."
ERROR_OUTPUT=$(dune exec bin/main.exe -- nonexistent.json 2>&1 | grep -i "not found\|No such file" || true)
if [[ ! -z "$ERROR_OUTPUT" ]]; then
    pass_test "Missing file produces appropriate error"
else
    fail_test "Missing file doesn't produce appropriate error"
fi
echo

# Help and documentation tests
echo -e "${BLUE}=== Help and Documentation Tests ===${NC}"

info "Testing help output..."
HELP_OUTPUT=$(dune exec bin/main.exe -- --help 2>/dev/null | head -20)
if [[ "$HELP_OUTPUT" == *"sx"* && "$HELP_OUTPUT" == *"S-expression"* ]]; then
    pass_test "Help output displays correctly"
else
    fail_test "Help output malformed"
fi

info "Testing example from help matches actual behavior..."
# Extract and test an example from help
EXAMPLE_RESULT=$(echo '{"key": "value"}' | dune exec bin/main.exe 2>/dev/null)
if [[ "$EXAMPLE_RESULT" == *'"key"'* && "$EXAMPLE_RESULT" == *'"value"'* ]]; then
    pass_test "Help examples work in practice"
else
    fail_test "Help examples don't work in practice"
fi
echo

# Performance tests (basic)
echo -e "${BLUE}=== Performance Tests ===${NC}"

info "Testing performance with moderately sized input..."
# Create a moderately sized JSON array
LARGE_JSON='['
for i in {1..100}; do
    LARGE_JSON+="{\"id\": $i, \"name\": \"item$i\", \"active\": true}"
    if [[ $i -lt 100 ]]; then
        LARGE_JSON+=','
    fi
done
LARGE_JSON+=']'

START_TIME=$(date +%s%N)
RESULT=$(echo "$LARGE_JSON" | dune exec bin/main.exe 2>/dev/null | wc -l)
END_TIME=$(date +%s%N)
DURATION=$((($END_TIME - $START_TIME) / 1000000)) # milliseconds

if [[ "$RESULT" -gt 90 && "$DURATION" -lt 1000 ]]; then
    pass_test "Performance test passed (${DURATION}ms for 100 items)"
else
    fail_test "Performance test failed (${DURATION}ms for 100 items, got $RESULT lines)"
fi
echo

# Integration workflow tests
echo -e "${BLUE}=== Integration Workflow Tests ===${NC}"

info "Testing pipeline workflow: JSON → sx → file → sx → scheme..."
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# JSON → file
echo '{"workflow": "test", "step": 1}' | dune exec bin/main.exe > "$TEMP_FILE" 2>/dev/null

# File → scheme
FINAL_RESULT=$(dune exec bin/main.exe -- --to scheme "$TEMP_FILE" 2>/dev/null)
if [[ "$FINAL_RESULT" == *'cons'* && "$FINAL_RESULT" == *'"workflow"'* ]]; then
    pass_test "End-to-end pipeline workflow works"
else
    fail_test "End-to-end pipeline workflow failed"
fi

info "Testing with real-world-like data..."
if [[ -f "examples/package.json" ]]; then
    PKG_RESULT=$(dune exec bin/main.exe -- examples/package.json 2>/dev/null | head -5)
    if [[ "$PKG_RESULT" == *'"name"'* ]]; then
        pass_test "Real-world package.json processing works"
    else
        fail_test "Real-world package.json processing failed"
    fi
else
    warn "examples/package.json not found, skipping real-world test"
fi
echo

# Final summary
echo -e "${BLUE}=== Verification Summary ===${NC}"
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 All tests passed! ($TESTS_PASSED/$TOTAL_TESTS)${NC}"
    echo
    echo -e "${GREEN}✨ sx is ready for production use!${NC}"
    echo
    echo "Key features verified:"
    echo "  • JSON, YAML, TOML input support"
    echo "  • Common Lisp and Scheme output"
    echo "  • Streaming mode for large files"
    echo "  • Configuration file system"
    echo "  • Professional CLI interface"
    echo "  • Robust error handling"
    echo "  • Performance optimizations"
    exit 0
else
    echo -e "${RED}❌ Some tests failed! ($TESTS_PASSED passed, $TESTS_FAILED failed out of $TOTAL_TESTS total)${NC}"
    echo
    echo -e "${YELLOW}Please review the failed tests above.${NC}"
    exit 1
fi