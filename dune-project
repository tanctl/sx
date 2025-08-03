(lang dune 3.0)

(package
 (name sx)
 (synopsis "S-expression converter for JSON, YAML, and TOML")
 (description "sx converts structured data from JSON, YAML, and TOML into Common Lisp or Scheme S-expressions. Features automatic format detection, streaming processing for large files, batch validation, configurable output formatting, pipeline performance analysis, and AST inspection capabilities.")
 (depends
  ocaml
  dune
  yojson
  yaml
  cmdliner))