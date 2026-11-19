{ config, pkgs, lib, ... }:

let
  lua = lib.generators.mkLuaInline;

  bind = key: action: {
    _args = [ (lua ''mod .. " + ${key}"'') (lua action) ];
  };

  media = key: cmd: {
    _args = [
      key
      (lua ''hl.dsp.exec_cmd("${cmd}")'')
      { locked = true; repeating = true; }
    ];
  };

  mouse = key: action: {
    _args = [ (lua ''mod .. " + ${key}"'') (lua action) { mouse = true; } ];
  };

  workspaceBinds = lib.concatMap (i:
    let
      n = toString i;
      key = if i == 10 then "0" else n;
    in [
      (bind key ''hl.dsp.focus({ workspace = ${n} })'')
      (bind "SHIFT + ${key}" ''hl.dsp.window.move({ workspace = ${n} })'')
    ]) (lib.range 1 10);
in

{
  imports = [ ./qs-theme.nix ];

   home.username = "f0rest3xplorer";
   home.homeDirectory = "/home/f0rest3xplorer";
   home.stateVersion = "26.05";

   xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink "/home/f0rest3xplorer/nixos-config/quickshell";
   xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "/home/f0rest3xplorer/nixos-config/nvim";

   programs.home-manager.enable = true;

   # Make fonts installed via home.packages visible to fontconfig
   fonts.fontconfig.enable = true;

   wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      settings = {
         mod = { _var = "SUPER"; };

         config = {
            animations = {
               enabled = false;
            };
            general = {
                border_size = 2;
                gaps_in = 3;     # between windows
                gaps_out = 8;   # screen edge, matches your bar's 20px side margins
                col = {
                  active_border   = "rgba(3dd1b0ff)";
                  inactive_border = "rgba(1c2f31ff)";
                };
              };

              decoration = {
                rounding = 12;
                active_opacity = 1.0;
                inactive_opacity = 0.90;
                blur   = { enabled = false; };
                shadow = { enabled = false; };
              };

              cursor = { no_hardware_cursors = true; };
              
         };

         # window rules (Nix syntax, not Lua)
         window_rule = {
            match.class = "foot";
            opacity = "0.93 override 0.8 override 1.0 override";
         };

         # key bindings
         bind = [
            # apps
            (bind "Return" ''hl.dsp.exec_cmd("foot")'')
            (bind "D"      ''hl.dsp.exec_cmd("wofi --show drun")'')
            (bind "B"      ''hl.dsp.exec_cmd("firefox")'')
            (bind "E"      ''hl.dsp.exec_cmd("dolphin")'')
            (bind "SPACE"  ''hl.dsp.exec_cmd("qs ipc call applauncher toggle")'')

            # window management
            (bind "C"      ''hl.dsp.window.close()'')
            (bind "V"      ''hl.dsp.window.float({ action = "toggle" })'')
            (bind "F"      ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })'')
            (bind "P"      ''hl.dsp.window.pseudo()'')
            (bind "J"      ''hl.dsp.layout("togglesplit")'')
            (bind "Tab"    ''hl.dsp.window.cycle_next()'')

            # focus with arrow keys and vim keys
            (bind "left"   ''hl.dsp.focus({ direction = "left" })'')
            (bind "right"  ''hl.dsp.focus({ direction = "right" })'')
            (bind "up"     ''hl.dsp.focus({ direction = "up" })'')
            (bind "down"   ''hl.dsp.focus({ direction = "down" })'')
            (bind "H"      ''hl.dsp.focus({ direction = "left" })'')
            (bind "L"      ''hl.dsp.focus({ direction = "right" })'')

            # move windows
            (bind "SHIFT + left"   ''hl.dsp.window.move({ direction = "left" })'')
            (bind "SHIFT + right"  ''hl.dsp.window.move({ direction = "right" })'')
            (bind "SHIFT + up"     ''hl.dsp.window.move({ direction = "up" })'')
            (bind "SHIFT + down"   ''hl.dsp.window.move({ direction = "down" })'')

            # resize windows
            (bind "CTRL + left"    ''hl.dsp.window.resize({ x = -40, y = 0, relative = true })'')
            (bind "CTRL + right"   ''hl.dsp.window.resize({ x = 40, y = 0, relative = true })'')
            (bind "CTRL + up"      ''hl.dsp.window.resize({ x = 0, y = -40, relative = true })'')
            (bind "CTRL + down"    ''hl.dsp.window.resize({ x = 0, y = 40, relative = true })'')

            # scratchpad
            (bind "S"              ''hl.dsp.workspace.toggle_special("magic")'')
            (bind "SHIFT + S"      ''hl.dsp.window.move({ workspace = "special:magic" })'')

            # scroll through workspaces with the mouse wheel
            (bind "mouse_down"     ''hl.dsp.focus({ workspace = "e+1" })'')
            (bind "mouse_up"       ''hl.dsp.focus({ workspace = "e-1" })'')

            # screenshot of a selected region to clipboard
            (bind "SHIFT + P"      ''hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]])'')

            # session
            (bind "SHIFT + E"      ''hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'")'')

            # SUPER + left-drag moves, SUPER + right-drag resizes windows
            (mouse "mouse:272" "hl.dsp.window.drag()")
            (mouse "mouse:273" "hl.dsp.window.resize()")

            # Themes
            (bind "T"         ''hl.dsp.exec_cmd("qs ipc call theme next")'')
            (bind "SHIFT + T" ''hl.dsp.exec_cmd("qs ipc call theme prev")'')


         ] ++ workspaceBinds;

         # startup apps
         on = {
            _args = [
               "hyprland.start"
               (lib.generators.mkLuaInline ''
                  function()
                    hl.exec_cmd("quickshell")
                  end
               '')
            ];
         };
      };
   };

   home.packages = with pkgs; [
      gh
      firefox
      kitty
      foot
      wofi
      vscodium
      btop
      # waybar
      dunst
      quickshell
      neovim
      # lazyvim tools
      gcc gnumake ripgrep fd lazygit tree-sitter nodejs unzip
      lua-language-server nil stylua
      # for key bindings
      grim slurp wl-clipboard
      swaybg
      # fonts and icons for the bar
      material-symbols
      nerd-fonts.jetbrains-mono
      # media
      cider-2
   ];

   home.sessionVariables.EDITOR = "nvim";

}
