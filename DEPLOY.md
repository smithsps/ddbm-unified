# Deploy to NixOS

## First Time Setup

### 1. On Server (your deployment server)

```bash
# Clone repo
cd /etc/nixos
sudo git clone <your-repo-url> ddbm

# Create secrets
sudo mkdir -p /etc/ddbm
sudo nano /etc/ddbm/secrets.env
```

Add to `/etc/ddbm/secrets.env`:
```bash
DISCORD_TOKEN=your_token
DISCORD_APP_ID=your_app_id
DISCORD_GUILD_ID=your_guild_id
DISCORD_BOT_CHANNEL=your_channel_id
SECRET_KEY_BASE=your_secret  # Generate with: nix shell nixpkgs#elixir -c mix phx.gen.secret
```

```bash
sudo chmod 600 /etc/ddbm/secrets.env
```

### 2. Add to NixOS Config

Add to your flake's `inputs`:
```nix
ddbm.url = "path:/etc/nixos/ddbm";
```

Add to your configuration:
```nix
{
  imports = [ ddbm.nixosModules.default ];

  services.ddbm = {
    enable = true;
    host = "0.0.0.0";
    port = 4000;
    openFirewall = true;
    environmentFile = "/etc/ddbm/secrets.env";
  };
}
```

Deploy:
```bash
sudo nixos-rebuild switch
```

## Updates

From your dev machine:
```bash
# Set DEPLOY_SERVER in .env file first
./deploy.sh
```

## Quick Commands

```bash
# View logs
ssh $DEPLOY_SERVER sudo journalctl -u ddbm -f

# Restart
ssh $DEPLOY_SERVER sudo systemctl restart ddbm

# Status
ssh $DEPLOY_SERVER sudo systemctl status ddbm
```
