{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.wifi;

  # Add your WiFi networks here
  # For WPA networks: "SSID" = { pskRaw = "ext:key_name"; };
  # For open networks: "SSID" = { };
  # The ext: prefix references keys in sops secrets (wifi/credentials)
  sharedNetworks = {
    # Example:
    # "MyNetwork" = { pskRaw = "ext:mynetwork"; };
    # "CoffeeShop" = { };
  };
in
{
  options.modules.wifi = {
    enable = lib.mkEnableOption "Shared WiFi configuration using SOPS secrets";

    extraNetworks = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional per-host networks to merge with shared networks";
    };

    userControlled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow user control via wpa_cli";
    };

    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Wireless interfaces to use (e.g. [ \"wlp9s0\" ]). Empty list uses auto-detection.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.wireless = {
      enable = true;
      inherit (cfg) userControlled;
      networks = sharedNetworks // cfg.extraNetworks;
    }
    // lib.optionalAttrs (cfg.interfaces != [ ]) { inherit (cfg) interfaces; };
  };
}
