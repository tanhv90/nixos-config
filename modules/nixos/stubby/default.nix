{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.stubby;
in
{
  options = {
    modules.stubby.enable = lib.mkEnableOption "Stubby services";
  };
  config = lib.mkIf cfg.enable {
    services.stubby = {
      enable = true;
      settings = pkgs.stubby.passthru.settingsExample // {
        upstream_recursive_servers = [
          {
            address_data = "1.1.1.1";
            tls_auth_name = "cloudflare-dns.com";
          }
          {
            address_data = "1.0.0.1";
            tls_auth_name = "cloudflare-dns.com";
          }
          {
            address_data = "2606:4700:4700::1111";
            tls_auth_name = "cloudflare-dns.com";
          }
          {
            address_data = "2606:4700:4700::1001";
            tls_auth_name = "cloudflare-dns.com";
          }
        ];
      };
    };

    # Route all DNS through Stubby
    networking.nameservers = lib.mkForce [
      "127.0.0.1"
      "::1"
    ];

    # Prevent DHCP from overwriting resolv.conf
    networking.dhcpcd.extraConfig = "nohook resolv.conf";
  };
}
