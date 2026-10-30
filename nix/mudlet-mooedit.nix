# MooEdit, local editing for MOOs in Mudlet (MCP 2.1 simpleedit and MCP 1.0
# `#$# edit`), from ~/Source/mudlet-mooedit (not published anywhere yet, so
# this builds from that working copy).
#
# share/mudlet/mooedit/mooedit.lua  the code
# share/mudlet/mooedit/MooEdit.mpackage  a loader package: its script only
#   dofile()s the code from the user profile, so a rebuild updates MooEdit in
#   every Mudlet profile it's installed in, without reinstalling. Install it
#   once per profile, in Mudlet's input line:
#     lua installPackage([[/etc/profiles/per-user/jwm/share/mudlet/mooedit/MooEdit.mpackage]])
{ stdenvNoCC, python3 }:

stdenvNoCC.mkDerivation {
  pname = "mudlet-mooedit";
  version = "0.1";

  src = builtins.path {
    path = /home/jwm/Source/mudlet-mooedit;
    name = "mudlet-mooedit-src";
    filter = path: type: baseNameOf path != "build";
  };

  nativeBuildInputs = [ python3 ];

  buildPhase = ''
    python3 build.py --loader /etc/profiles/per-user/jwm/share/mudlet/mooedit/mooedit.lua
  '';

  installPhase = ''
    install -Dm644 build/mooedit.lua build/MooEdit.mpackage -t $out/share/mudlet/mooedit
  '';
}
