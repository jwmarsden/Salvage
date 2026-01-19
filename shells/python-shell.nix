# shell.nix
with import <nixpkgs> {};

(pkgs.python3.withPackages (ps: with ps; [
  # Add necessary Python packages here
  ipykernel
  ipython
  jupyterlab
  numpy
  pip
  pandas
  geopandas
  pyproj
  shapely
  matplotlib
  cartopy
  geodatasets
  folium
])).env
