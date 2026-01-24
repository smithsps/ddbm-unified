{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ddbm;
in
{
  options.services.ddbm = {
    enable = mkEnableOption "DDBM Discord Database Management service";

    package = mkOption {
      type = types.package;
      description = "The DDBM package to use (automatically set when using the flake's nixosModule)";
    };

    user = mkOption {
      type = types.str;
      default = "ddbm";
      description = "User account under which DDBM runs";
    };

    group = mkOption {
      type = types.str;
      default = "ddbm";
      description = "Group under which DDBM runs";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/ddbm";
      description = "Directory where DDBM stores its data (database)";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host address for the web server";
    };

    port = mkOption {
      type = types.port;
      default = 4000;
      description = "Port for the web server";
    };

    logLevel = mkOption {
      type = types.enum ["debug" "info" "warning" "error"];
      default = "info";
      description = "Log level for the application";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to environment file containing secrets.
        Should include:
          DISCORD_TOKEN=...
          DISCORD_APP_ID=...
          DISCORD_GUILD_ID=...
          DISCORD_BOT_CHANNEL=...
          SECRET_KEY_BASE=...
      '';
    };

    discord = {
      token = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Discord bot token (prefer using environmentFile)";
      };

      appId = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Discord application ID";
      };

      guildId = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Discord guild (server) ID";
      };

      botChannel = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Discord bot channel ID";
      };
    };

    secretKeyBase = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Secret key base for Phoenix (prefer using environmentFile).
        Generate with: mix phx.gen.secret
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for the web interface";
    };

    enableHealthCheck = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable systemd health check for the web server";
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };

    users.groups.${cfg.group} = {};

    systemd.services.ddbm = {
      description = "DDBM Discord Database Management";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        RELEASE_NODE = "ddbm@${cfg.host}";
        PHX_HOST = cfg.host;
        PHX_SERVER = "true";
        PORT = toString cfg.port;
        DATABASE_PATH = "${cfg.dataDir}/ddbm.db";
        RELEASE_TMP = "/run/ddbm";
        LOG_LEVEL = cfg.logLevel;
      } // optionalAttrs (cfg.discord.token != null) {
        DISCORD_TOKEN = cfg.discord.token;
      } // optionalAttrs (cfg.discord.appId != null) {
        DISCORD_APP_ID = cfg.discord.appId;
      } // optionalAttrs (cfg.discord.guildId != null) {
        DISCORD_GUILD_ID = cfg.discord.guildId;
      } // optionalAttrs (cfg.discord.botChannel != null) {
        DISCORD_BOT_CHANNEL = cfg.discord.botChannel;
      } // optionalAttrs (cfg.secretKeyBase != null) {
        SECRET_KEY_BASE = cfg.secretKeyBase;
      };

      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        RuntimeDirectory = "ddbm";
        RuntimeDirectoryMode = "0755";
        StateDirectory = "ddbm";
        StateDirectoryMode = "0750";

        # Load secrets from environment file if provided
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        PrivateMounts = true;

        # Start the release
        ExecStart = "${cfg.package}/bin/ddbm start";
        ExecStop = "${cfg.package}/bin/ddbm stop";

        # Health check
        ExecStartPost = mkIf cfg.enableHealthCheck (pkgs.writeShellScript "ddbm-health-check" ''
          echo "Waiting for DDBM to become ready..."
          for i in {1..30}; do
            if ${pkgs.curl}/bin/curl -sf http://${cfg.host}:${toString cfg.port}/ >/dev/null 2>&1; then
              echo "DDBM is ready and responding"
              exit 0
            fi
            echo "Attempt $i/30: Service not ready yet..."
            sleep 1
          done
          echo "ERROR: DDBM failed to start within 30 seconds"
          exit 1
        '');

        # Restart policy
        Restart = "on-failure";
        RestartSec = "5s";
      };

      preStart = ''
        # Ensure data directory exists and has correct permissions
        mkdir -p ${cfg.dataDir}
        chmod 750 ${cfg.dataDir}

        # Run migrations on startup
        echo "Running database migrations..."
        if ! ${cfg.package}/bin/ddbm eval "Ddbm.Release.migrate()"; then
          echo "ERROR: Database migrations failed!"
          exit 1
        fi
        echo "Migrations completed successfully"
      '';
    };

    # Open firewall if requested
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
