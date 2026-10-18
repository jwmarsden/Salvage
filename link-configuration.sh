
ln -s $HOME/nix-config/nix/configuration.nix /etc/nixos/configuration.nix
ln -s $HOME/nix-config/nix/macbook12-audio.nix /etc/nixos/macbook12-audio.nix
ln -s $HOME/nix-config/nix/power.nix /etc/nixos/power.nix

mkdir -p ~/.config/sway ~/.config/waybar
ln -s $HOME/nix-config/sway/config ~/.config/sway/config
ln -s $HOME/nix-config/waybar/config.jsonc ~/.config/waybar/config.jsonc
ln -s $HOME/nix-config/waybar/style.css ~/.config/waybar/style.css
