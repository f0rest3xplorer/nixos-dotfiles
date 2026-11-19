# Home-manager wiring for the Quickshell system-wide theme.
#
# The theme script writes generated files into ~/.local/state/qs-theme/ (a
# writable place). This module links them into each app's config folder, so the
# app configs just `include` / `require` / `@import` a normal-looking file.
#
# Import it from your home config:   imports = [ ./qs-theme.nix ];
{ config, lib, pkgs, ... }:

let
  themeDir = "${config.xdg.stateHome}/qs-theme";
  link = name: config.lib.file.mkOutOfStoreSymlink "${themeDir}/${name}";
in
{
  # 1. Generated files -> app config folders (links to files that Quickshell rewrites)
  xdg.configFile = {
    "hypr/theme.lua".source       = link "hyprland.lua";
    "kitty/theme.conf".source     = link "kitty.conf";
    "alacritty/theme.toml".source = link "alacritty.toml";
    "gtk-3.0/colors.css".source   = link "gtk.css";
    "gtk-4.0/colors.css".source   = link "gtk.css";
  };

  # 2. Create empty placeholders on activation so the links never dangle before
  #    Quickshell has run for the first time (a missing require() file would
  #    otherwise abort your Hyprland config).
  home.activation.qsThemeSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${themeDir}"
    for f in hyprland.lua kitty.conf alacritty.toml gtk.css; do
      [ -e "${themeDir}/$f" ] || touch "${themeDir}/$f"
    done
  '';

  # 3. Programs the theme script runs. They must be on the PATH Quickshell sees.
  home.packages = [
    pkgs.python3   # runs apply-theme.py
    pkgs.procps    # pkill, to make kitty reload
    pkgs.dconf     # light/dark preference
  ];

  # 4. Point the apps at the linked files
  programs.kitty.extraConfig = ''
    include theme.conf
  '';

  programs.alacritty.settings.general.import = [
    "${config.xdg.configHome}/alacritty/theme.toml"
  ];

  gtk.gtk3.extraCss = ''@import url("colors.css");'';
  gtk.gtk4.extraCss = ''@import url("colors.css");'';

  # Hyprland: add  require("theme")  to hyprland.lua after your own border
  # settings. How you add it depends on how hyprland.lua is managed; see notes.
}
