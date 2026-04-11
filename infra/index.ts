import * as pulumi from "@pulumi/pulumi";
import * as hcloud from "@pulumi/hcloud";

// ---------------------------------------------------------------------------
// Configuration
// Read values from Pulumi.prod.yaml (non-secret) and encrypted config (secret)
// ---------------------------------------------------------------------------
const config = new pulumi.Config();

const serverType     = config.require("serverType");       // e.g. "cx32"
const serverLocation = config.require("serverLocation");   // e.g. "nbg1"
const serverImage    = config.require("serverImage");      // e.g. "ubuntu-24.04"
const sshKeyName     = config.require("sshKeyName");       // Name in Hetzner console

// Hetzner API token — stored encrypted, never in plain config files.
// Set it with: pulumi config set --secret hcloudToken <your-token>
const hcloudToken = config.requireSecret("hcloudToken");

// ---------------------------------------------------------------------------
// Provider
// We pass the token explicitly so the same Pulumi program can target
// different Hetzner projects by switching stacks.
// ---------------------------------------------------------------------------
const provider = new hcloud.Provider("hcloud", {
    token: hcloudToken,
});

// ---------------------------------------------------------------------------
// SSH Key lookup
// We reference an existing key uploaded to Hetzner Cloud — we don't manage
// the key material itself in Pulumi (that would require storing it here).
// Upload your public key at: https://console.hetzner.cloud → Security → SSH Keys
// ---------------------------------------------------------------------------
const sshKey = hcloud.getSshKeyOutput(
    { name: sshKeyName },
    { provider }
);

// ---------------------------------------------------------------------------
// Firewall
// Only allow inbound traffic on ports 22 (SSH), 80 (HTTP), 443 (HTTPS).
// All other inbound ports are blocked. Outbound is unrestricted.
// ---------------------------------------------------------------------------
const firewall = new hcloud.Firewall("personal-cloud-firewall", {
    name: "personal-cloud-firewall",
    rules: [
        {
            direction: "in",
            protocol: "tcp",
            port: "22",
            sourceIps: ["0.0.0.0/0", "::/0"],  // SSH — consider restricting to your IP
            description: "Allow SSH",
        },
        {
            direction: "in",
            protocol: "tcp",
            port: "80",
            sourceIps: ["0.0.0.0/0", "::/0"],
            description: "Allow HTTP (redirected to HTTPS by Nginx)",
        },
        {
            direction: "in",
            protocol: "tcp",
            port: "443",
            sourceIps: ["0.0.0.0/0", "::/0"],
            description: "Allow HTTPS",
        },
    ],
}, { provider });

// ---------------------------------------------------------------------------
// Server
// CX32 in Nuremberg (NBG1) — Ubuntu 24.04 LTS.
// The server runs Nginx, Docker, and all self-hosted services.
// ---------------------------------------------------------------------------
const server = new hcloud.Server("personal-cloud-server", {
    name: "personal-cloud",
    serverType: serverType,
    location: serverLocation,
    image: serverImage,
    sshKeys: [sshKey.id],           // Inject SSH key at creation time
    firewalls: [
        { firewallId: firewall.id.apply(id => parseInt(id)) },
    ],
    // Cloud-init script: basic hardening on first boot
    userData: `#!/bin/bash
# Disable root password login (SSH key only)
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
`,
}, { provider });

// ---------------------------------------------------------------------------
// DNS
// Hetzner DNS is managed separately via their DNS console or DNS provider API.
// The following A records should point to the server IP below:
//
//   vault.yourdomain.com   → <server IP>   (Vaultwarden)
//   cloud.yourdomain.com   → <server IP>   (Nextcloud)
//   photos.yourdomain.com  → <server IP>   (Immich — future)
//   media.yourdomain.com   → <server IP>   (Jellyfin — future)
//   status.yourdomain.com  → <server IP>   (Uptime Kuma — future)
//
// If you prefer to manage DNS with Pulumi, see @pulumi/hcloud DNS resources
// or use a provider for your registrar (e.g. Gandi.net).
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Stack Outputs
// These are printed after `pulumi up` and can be read with `pulumi stack output`
// ---------------------------------------------------------------------------
export const serverIp   = server.ipv4Address;
export const serverIpv6 = server.ipv6Address;
export const serverName = server.name;

export const dnsReminder = pulumi.interpolate`
Create these DNS A records pointing to: ${server.ipv4Address}
  vault.yourdomain.com
  cloud.yourdomain.com
  photos.yourdomain.com  (future)
  media.yourdomain.com   (future)
  status.yourdomain.com  (future)
`;
