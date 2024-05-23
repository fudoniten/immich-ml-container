{ config, lib, pkgs, ... }:

with lib;
let cfg = config.services.immichMlContainer;

in {
  options.services.immichMlContainer = with types; {
    enable = mkEnableOption "Enable machine learning container.";

    hostnames = mkOption {
      type = listOf str;
      description = "List of hostnames at which this container can be reached.";
    };

    port = mkOption {
      type = port;
      description = "Port on which to listen for connections.";
      default = 3003;
    };

    state-directory = mkOption {
      type = str;
      description = "Path on which to store service state.";
    };

    immich-version = mkOption { type = str; };

    debug = mkEnableOption "Enable debugging logs.";

    # TODO: maybe have different types?
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.state-directory} 0750 root root - -" ];

    virtualisation.oci-containers.containers = {
      immich-machine-learning = {
        autoStart = true;
        image =
          "ghcr.io/immich-app/immich-machine-learning:${cfg.immich-version}-cuda";
        volumes = [ "${cfg.state-directory}:/cache" ];
        ports = [ "${toString cfg.port}:3003" ];
        extraOptions = [ "--gpus=all" ];
      };
    };

    services.nginx = {
      enable = true;
      clientMaxBodySize = "1024M";
      virtualHosts = genAttrs cfg.hostnames (hostname: {
        enableACME = false;
        forceSSL = false;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          extraConfig = ''
            proxy_request_buffering off;
          '';
          recommendedProxySettings = true;
          proxyWebsockets = true;
        };
      });
    };
  };
}
