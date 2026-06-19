{ ... }:

{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main = {
        # Ergonomic remaps – run `sudo keyd monitor` to find device-specific IDs
        capslock   = "escape";   # caps → esc
        "meta+h"   = "left";     # vim-style arrows with Super
        "meta+j"   = "down";
        "meta+k"   = "up";
        "meta+l"   = "right";
      };
    };
  };
}
