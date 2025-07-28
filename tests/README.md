# sx Tests

This directory contains the test suite for the sx tool.

## Structure

```
tests/
├── unit/                 # unit tests for individual modules
│   ├── test_parsers.ml   # JSON/YAML/TOML parsing tests
│   ├── test_generators.ml# s-expression generation tests
│   ├── test_config.ml    # configuration loading tests
│   └── test_error_handling.ml # error handling tests
├── integration/          # end-to-end integration tests
│   ├── test_cli.ml       # CLI functionality tests
│   ├── test_streaming.ml # streaming mode tests
│   ├── test_batch.ml     # batch processing tests
│   └── test_auto_detect.ml # format detection tests
├── property/             # property-based tests
│   └── test_basic_invariants.ml # basic invariant tests
└── fixtures/             # test data files
    ├── valid/            # valid test files
    ├── invalid/          # invalid test files
    └── medium_files/     # larger files for streaming tests
```

## Running Tests

```bash
# Run all tests
dune runtest

# Run specific test files
dune exec tests/unit/test_parsers.exe
dune exec tests/integration/test_cli.exe

# Run property tests
dune exec tests/property/test_basic_invariants.exe
```