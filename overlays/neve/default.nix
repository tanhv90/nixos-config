{ inputs, ... }:
_final: prev: {
  nixvim = inputs.neve.packages.${prev.stdenv.hostPlatform.system}.nvim;
}
