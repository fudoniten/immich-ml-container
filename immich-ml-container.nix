{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.immichMlContainer;

  immichMlConfigYaml = pkgs.writeText "immich-ml-compose.yml" (builtins.toJSON {
    version = "3.4";
    networks.default.name = "immich-ml";
    volumes = { };
    services.immich-ml = {
      image =
        "ghcr.io/immich-app/immich-machine-learning:${cfg.immich-version}-cuda";
      deploy.resources.reservations.devices = [{
        driver = "nvidia";
        count = 1;
        capabilities = [ "gpu" ];
      }];
      ports = [ "${toString cfg.port}:3003" ];
      restart = "always";
      volumes = [ "${cfg.state-directory}:/cache" ];
    };
  });

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

    immich-version = mkOption {
      type = str;
      description = "";
    };

    # TODO: maybe have different types?
  };

  config = mkIf cfg.enable {
    systemd = {
      services.immich-machine-learning = {
        after = [ "network-online.target" ];
        before = [ "nginx.service" ];
        path = with pkgs; [ podman-compose ];
        serviceConfig = {
          ExecStart = pkgs.writeShellScript "immich-machine-learning" ''
            podman-compose -f ${immichMlConfigYaml}
          '';
        };
      };

      tmpfiles.rules = [ "d ${cfg.state-directory} 0750 root root - -" ];
    };

    services.nginx = {
      enable = true;
      virtualHosts = genAttrs cfg.hostnames (hostname: {
        enableACME = false;
        forceSSL = false;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          recommendedProxySettings = true;
        };
      });
    };
  };
}
