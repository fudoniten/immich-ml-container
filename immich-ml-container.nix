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

    metrics-port = mkOption {
      type = port;
      description = "Port on which to supply metrics.";
      default = 9090;
    };

    state-directory = mkOption {
      type = str;
      description = "Path on which to store service state.";
    };

    workers = mkOption {
      type = int;
      description = "Number of workers to run.";
      default = 3;
    };

    threads = mkOption {
      type = int;
      description = "Number of request threads to run.";
      default = 12;
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
        ports =
          [ "${toString cfg.port}:3003" "${toString cfg.metrics-port}:9090" ];
        extraOptions = [ "--gpus=all" ];
        environment = {
          IMMICH_METRICS = "true";
          MACHINE_LEARNING_WORKERS = toString cfg.workers;
          MACHINE_LEARNING_REQUEST_THREADS = toString cfg.threads;
        };
      };
    };

    services.nginx = {
      enable = true;
      clientMaxBodySize = "1024M";
      commonHttpConfig = ''
        log_format with_response_time '$remote_addr - $remote_user [$time_local] '
                     '"$request" $status $body_bytes_sent '
                     '"$http_referer" "$http_user_agent" '
                     '"$request_time" "$upstream_response_time"';
        access_log /var/log/nginx/access.log with_response_time;
      '';
      virtualHosts = genAttrs cfg.hostnames (hostname: {
        enableACME = false;
        forceSSL = false;
        locations."/metrics" = {
          proxyPass = "http://127.0.0.1:${toString cfg.metrics-port}";
          recommendedProxySettings = true;
        };
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          recommendedProxySettings = true;
          proxyWebsockets = true;
        };
      });
    };
  };
}
