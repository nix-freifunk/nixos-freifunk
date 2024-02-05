{ lib }:
let
  hexDigits = [ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f" ];

  intToHex = num: if num < 16
    then builtins.elemAt hexDigits num
    else (intToHex (builtins.div num 16)) + (builtins.elemAt hexDigits (lib.mod num 16));
in
  num: intToHex num
