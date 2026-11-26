# moocat, the MOO client, built from its GitHub repo at a pinned commit with
# the repo's own Nix package (packaging/nix/moocat.nix) and the tinyjs here.
# To update: push moocat, then set rev to the new commit and sha256 to
#   nix-prefetch-url --unpack https://github.com/jwmarsden/moocat/archive/<rev>.tar.gz
{ callPackage, tinyjs }:

let
  rev = "93f2807ba9bad43f5fa7a25f4ae829bceefdd098";
  src = builtins.fetchTarball {
    url = "https://github.com/jwmarsden/moocat/archive/${rev}.tar.gz";
    sha256 = "1bmpjxwb2sj6nabkdznsnlfxypz205f9ff0lazlfjyxaiv64wwwg";
  };
in
callPackage "${src}/packaging/nix/moocat.nix" { inherit tinyjs; }
