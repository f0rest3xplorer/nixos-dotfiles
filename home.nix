{ config, pkgs, lib, ...}:

{
   home.username = "f0rest3xplorer";
   home.homeDirectory = "/home/f0rest3xplorer";
   home.stateVersion = "26.05";

   xdg.configFile."quickshell/shell.qml".source = config.lib.file.mkOutOfStoreSymlink "/home/f0rest3xplorer/nix-os/shell.qml";

   programs.home-manager.enable = true;

   wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      settings = {
         mod = { _var = "SUPER"; };

         #key bindings
         bind = [
            {
               _args = [
                  (lib.generators.mkLuaInline ''mod .. " + Return"'')
                  (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("foot")'')
               ];
            }
            {
               _args = [
                  (lib.generators.mkLuaInline ''mod .. " + D"'')
                  (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wofi --show drun")'')
               ];
            }
         ];

         #startup apps
         on = {
            _args = [
               "hyprland.start"
               (lib.generators.mkLuaInline ''
	       function()
	          hl.exec_cmd("waybar")
		  hl.exec_cmd("env QT_QUICK_BACKEND=software quickshell")
	          hl.exec_cmd("quickshell")
	       end
            '')
            ];
         };
      };
   };

   home.packages = with pkgs; [
      firefox
      kitty
      foot
      wofi
      waybar
      dunst
      ripgrep
      neovim
      quickshell
   ];
}
