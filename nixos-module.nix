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
      default = pkgs.ddbm;
      description = "The DDBM package to use";
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
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = {};

    systemd.services.ddbm = {
      description = "DDBM Discord Database Management";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        RELEASE_NODE = "ddbm@${cfg.host}";
        PHX_HOST = cfg.host;
        PORT = toString cfg.port;
        DATABASE_PATH = "${cfg.dataDir}/ddbm.db";
        RELEASE_TMP = "/run/ddbm";
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

        # Load secrets from environment file if provided
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];

        # Start the release
        ExecStart = "${cfg.package}/bin/ddbm start";
        ExecStop = "${cfg.package}/bin/ddbm stop";

        # Restart policy
        Restart = "on-failure";
        RestartSec = "5s";
      };

      preStart = ''
        # Run migrations on startup
        ${cfg.package}/bin/ddbm eval "Ddbm.Release.migrate()"
      '';
    };

    # Open firewall if requested
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
