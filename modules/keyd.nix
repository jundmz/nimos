{ ... }:

{
  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];

      settings = {
        main = {
          esc = "`";
          capslock = "overload(nav, esc)";

          j = "overloadt(meta, j, 500)";
          f = "overloadt(meta, f, 500)";
          d = "overloadt(control, d, 500)";
          k = "overloadt(control, k, 500)";
          s = "overloadt(alt, s, 500)";
          l = "overloadt(alt, l, 500)";
          ";" = "overloadt(shift, ;, 500)";
          a = "overloadt(shift, a, 500)";
          m = "overloadt(meta, m, 500)";
        };

        "nav:C" = {
          j = "down";
          k = "up";
          h = "left";
          l = "right";
        };
      };
    };
  };
}
