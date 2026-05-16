(lang dune 3.19)

(name personal_symphony)

(generate_opam_files true)

(package
 (name personal_symphony)
 (synopsis "OCaml/ReScript Symphony service scaffold")
 (authors "MatheusBBarni <brehm.matheus@hotmail.com>")
 (maintainers "MatheusBBarni <brehm.matheus@hotmail.com>")
 (license "LicenseRef-Proprietary")
 (homepage "https://github.com/MatheusBBarni/symphony-orchestrator#readme")
 (bug_reports "https://github.com/MatheusBBarni/symphony-orchestrator/issues")
 (depends
  (ocaml (>= 5.1))
  (dune (>= 3.19))
  yojson
  cmdliner
  alcotest
  reason
  symphony-orchestrator-tui
  uutf
  toffee))
