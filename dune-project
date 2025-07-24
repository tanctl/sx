(lang dune 3.0)

(package
 (name sx)
 (synopsis "S-expression converter tool")
 (description "Convert between JSON, YAML and various S-expression formats")
 (depends
  ocaml
  dune
  yojson
  yaml
  cmdliner))