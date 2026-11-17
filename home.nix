{ config, pkgs, ...}:

{
   home.username = "f0rest3xplorer";
   home.homeDirectory = "/home/f0rest3xplorer";
   home.stateVersion = "26.05";

   programs.home-manager.enable = true;
}
