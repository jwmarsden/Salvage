# moocat, the MOO client, built from its GitHub repo at a pinned commit with
# the repo's own Nix package (packaging/nix/moocat.nix) and the tinyjs here.
# To update: push moocat, then set rev to the new commit and sha256 to
#   nix-prefetch-url --unpack https://github.com/jwmarsden/moocat/archive/<rev>.tar.gz
{ callPackage, tinyjs }:

let
  rev = "14284928eb37376a10ae2563b531269e75573c16";
  src = builtins.fetchTarball {
    url = "https://github.com/jwmarsden/moocat/archive/${rev}.tar.gz";
    sha256 = "1p6qh9bv1a2drcrdvfcxvrb9c8kn2249pmaizrqmzh20xqkyyx5b";
  };
in
callPackage "${src}/packaging/nix/moocat.nix" { inherit tinyjs; }
