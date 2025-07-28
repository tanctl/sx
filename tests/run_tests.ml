let () =
  Printf.printf "Running sx test suite...\n\n";
  
  Printf.printf "=== Unit Tests ===\n";
  Printf.printf "Run individual unit tests with:\n";
  Printf.printf "  dune exec tests/unit/test_parsers.exe\n";
  Printf.printf "  dune exec tests/unit/test_generators.exe\n";
  Printf.printf "  dune exec tests/unit/test_config.exe\n";
  Printf.printf "  dune exec tests/unit/test_error_handling.exe\n\n";
  
  Printf.printf "=== Integration Tests ===\n";
  Printf.printf "Run individual integration tests with:\n";
  Printf.printf "  dune exec tests/integration/test_cli.exe\n";
  Printf.printf "  dune exec tests/integration/test_streaming.exe\n";
  Printf.printf "  dune exec tests/integration/test_batch.exe\n";
  Printf.printf "  dune exec tests/integration/test_auto_detect.exe\n\n";
  
  Printf.printf "=== Property Tests ===\n";
  Printf.printf "Run property tests with:\n";
  Printf.printf "  dune exec tests/property/test_basic_invariants.exe\n\n";
  
  Printf.printf "Use 'dune runtest' to run all tests automatically.\n";
  Printf.printf "\nTest suite information displayed.\n"