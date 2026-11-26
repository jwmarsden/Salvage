# moocat, the MOO client, built from its GitHub repo at a pinned commit with
# the repo's own Nix package (packaging/nix/moocat.nix) and the tinyjs here.
# To update: push moocat, then set rev to the new commit and sha256 to
#   nix-prefetch-url --unpack https://github.com/jwmarsden/moocat/archive/<rev>.tar.gz
{ callPackage, tinyjs }:

let
  rev = "7419186c88fa62ec4f1017d4dba789c7cb0ad88b";
  src = builtins.fetchTarball {
    url = "https://github.com/jwmarsden/moocat/archive/${rev}.tar.gz";
    sha256 = "1xvnb0wg6sv3mlja705zrsbi005h76zah2rn19qq5gcvdp95k6f4";
  };
in
callPackage "${src}/packaging/nix/moocat.nix" { inherit tinyjs; }
