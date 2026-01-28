# Cloudflare Privacy Hardening Guide

This guide explains how to use Cloudflare for DNS-01 certificate validation while **maximizing privacy** and keeping your traffic fully self-hosted.

---

## TL;DR - What Cloudflare Sees vs Doesn't See

### What Cloudflare CAN See (Unavoidable):
- ❌ Your domain names
- ❌ DNS queries for your domains
- ❌ Your server's public IP address
- ❌ Temporary ACME challenge tokens

### What Cloudflare CANNOT See (With DNS-Only Mode):
- ✅ HTTP/HTTPS traffic content
- ✅ User data, passwords, cookies
- ✅ Database contents
- ✅ API requests/responses
- ✅ Internal service names
- ✅ Access logs

**Bottom Line:** Cloudflare acts like a phone book (DNS) - it tells people where to find you, but doesn't read your mail.

---

## DNS-Only Mode Configuration

### Step 1: Create Minimal API Token

Go to: https://dash.cloudflare.com/profile/api-tokens

Click **"Create Token"** → **"Create Custom Token"**

```
Token Name: Server-Helper DNS-01 (Minimal)

Permissions:
  Zone - DNS - Edit        ✓ (Required for DNS-01)
  Zone - Zone - Read       ✓ (Required to list zones)

Zone Resources:
  Include - Specific zone - tennogen.ca
  Include - Specific zone - publicpower.org
  (Add each domain you need certificates for)

Client IP Address Filtering: (Optional)
  Is in - Your server's public IP

TTL:
  Start Date: (today)
  End Date: 1 year from now (or never)
```

This token can **ONLY**:
- Create/delete TXT records (for ACME challenges)
- Read zone information

This token **CANNOT**:
- Read DNS query logs
- Modify A/AAAA records
- Access analytics
- Enable/disable proxy mode
- Access any Cloudflare features

### Step 2: Configure DNS Records as "DNS Only"

In Cloudflare Dashboard → DNS → Records:

| Type | Name | Content | Proxy Status |
|------|------|---------|--------------|
| A | @ | YOUR_PUBLIC_IP | **DNS Only** (gray cloud) |
| A | mealie | YOUR_PUBLIC_IP | **DNS Only** (gray cloud) |
| A | vault | YOUR_PUBLIC_IP | **DNS Only** (gray cloud) |
| A | * | YOUR_PUBLIC_IP | **DNS Only** (gray cloud) |

**IMPORTANT:** The cloud icon must be **GRAY** (DNS Only), not **ORANGE** (Proxied).

- **Gray Cloud (DNS Only):** Traffic goes directly to your server
- **Orange Cloud (Proxied):** Traffic routes through Cloudflare (they can see everything)

### Step 3: Disable All Cloudflare Features

Since you're using DNS-Only mode, disable everything else:

**Speed Tab:**
- [ ] Auto Minify: OFF
- [ ] Brotli: OFF
- [ ] Early Hints: OFF
- [ ] Rocket Loader: OFF

**Caching Tab:**
- [ ] Caching Level: OFF
- [ ] Browser Cache TTL: Respect Existing Headers
- [ ] Always Online: OFF

**Security Tab:**
- [ ] Security Level: Essentially Off
- [ ] Challenge Passage: OFF
- [ ] Browser Integrity Check: OFF
- [ ] WAF: OFF

**Network Tab:**
- [ ] HTTP/2: OFF (handled by your server)
- [ ] HTTP/3: OFF
- [ ] WebSockets: OFF
- [ ] Onion Routing: OFF
- [ ] IP Geolocation: OFF

**Scrape Shield Tab:**
- [ ] Email Address Obfuscation: OFF
- [ ] Server-side Excludes: OFF
- [ ] Hotlink Protection: OFF

**Analytics Tab:**
- [ ] Web Analytics: OFF (or just don't use the data)

### Step 4: Verify DNS-Only Mode

```bash
# Check that DNS resolves directly to your IP (not Cloudflare's)
dig mealie.tennogen.ca

# Should return YOUR IP, not Cloudflare's (104.x.x.x or 172.x.x.x)

# Verify no Cloudflare headers
curl -I https://mealie.tennogen.ca | grep -i cloudflare
# Should return nothing (no CF headers)
```

---

## Privacy Comparison: DNS-Only vs Proxied

| Feature | DNS-Only (Gray) | Proxied (Orange) |
|---------|-----------------|------------------|
| **Traffic Routing** | Direct to your server | Through Cloudflare |
| **SSL Termination** | Your server | Cloudflare |
| **Traffic Visibility** | None | Full access |
| **DDoS Protection** | ❌ None | ✅ Full |
| **CDN Caching** | ❌ None | ✅ Full |
| **WAF** | ❌ None | ✅ Full |
| **IP Hidden** | ❌ Exposed | ✅ Hidden |
| **Privacy** | ✅ Maximum | ⚠️ Limited |
| **Performance** | Server-dependent | CDN-accelerated |

### When to Use Each Mode

**Use DNS-Only (Privacy-First) When:**
- Self-hosting personal services
- Privacy is more important than DDoS protection
- You control your own security (firewall, fail2ban, etc.)
- Services are internal/private
- You want full control over traffic

**Use Proxied Mode When:**
- Running high-traffic public sites
- DDoS attacks are a real concern
- You need CDN caching
- Hiding origin IP is critical
- You trust Cloudflare with your data

---

## Alternative: Self-Hosted DNS

For **maximum privacy**, you can host your own DNS:

### Option 1: Self-Hosted Authoritative DNS

Use software like:
- **PowerDNS** - Full-featured DNS server
- **BIND9** - Industry standard
- **Knot DNS** - High-performance

Then use HTTP-01 or TLS-ALPN-01 challenges instead of DNS-01.

### Option 2: Privacy-Focused DNS Registrars

Some registrars offer DNS with better privacy:
- **Njalla** - Privacy-focused, accepts crypto
- **1984 Hosting** - Iceland-based, privacy laws
- **Gandi** - No-BS privacy policy

### Option 3: Local DNS + Different Challenge

If you're okay exposing port 443:

```yaml
certificates:
  public:
    challenge: "tls-alpn-01"  # No DNS provider needed
```

---

## Cloudflare API Token Security

### Secure Token Storage

```yaml
# In group_vars/vault.yml (encrypted)
vault_cloudflare_dns_api_token: "your-token-here"
```

Never store tokens in:
- Plain text files
- Environment variables in docker-compose.yml
- Git repositories (even private ones)

### Token Rotation

Rotate your API token periodically:

1. Create new token in Cloudflare
2. Update vault: `ansible-vault edit group_vars/vault.yml`
3. Redeploy Traefik: `ansible-playbook playbooks/setup-targets.yml --tags traefik`
4. Delete old token in Cloudflare

### Monitor Token Usage

Check Cloudflare Audit Logs:
- Dashboard → Account → Audit Log
- Filter by API Token usage
- Watch for unexpected activity

---

## Network-Level Privacy

### Block Cloudflare Analytics

If using Pi-hole, block Cloudflare analytics:

```
# Add to Pi-hole blocklist
static.cloudflareinsights.com
cloudflareinsights.com
```

### Firewall Rules

Only allow Cloudflare to create DNS records, not access your server:

```bash
# Your server should NOT have Cloudflare IPs in your firewall
# Only YOUR clients should access your server

# Example UFW rules (allow your network, block others)
sudo ufw allow from 192.168.0.0/16 to any port 443
sudo ufw allow from YOUR_PUBLIC_IP to any port 443
```

---

## Verification Checklist

After setup, verify privacy:

```bash
# 1. Check DNS returns YOUR IP (not Cloudflare's)
dig +short mealie.tennogen.ca
# Should return: YOUR_PUBLIC_IP (not 104.x.x.x)

# 2. Verify no Cloudflare headers
curl -sI https://mealie.tennogen.ca | grep -i "cf-\|cloudflare"
# Should return: nothing

# 3. Check certificate issuer
echo | openssl s_client -connect mealie.tennogen.ca:443 2>/dev/null | openssl x509 -noout -issuer
# Should return: Let's Encrypt (not Cloudflare)

# 4. Verify direct connection
traceroute mealie.tennogen.ca
# Should go directly to your IP (not through Cloudflare)
```

---

## Summary

| Setting | Privacy-Optimized Value |
|---------|------------------------|
| Proxy Status | DNS Only (Gray Cloud) |
| API Token Permissions | Zone:DNS:Edit, Zone:Zone:Read only |
| Caching | Disabled |
| Analytics | Disabled |
| WAF | Disabled |
| SSL Mode | Not applicable (DNS only) |
| All other features | Disabled |

**With this configuration:**
- ✅ Cloudflare only provides DNS resolution
- ✅ All traffic goes directly to your server
- ✅ Your SSL certificates are from Let's Encrypt
- ✅ No traffic inspection or logging by Cloudflare
- ✅ Full control over your data

---

## Further Reading

- [Cloudflare API Tokens](https://developers.cloudflare.com/api/tokens/)
- [DNS-Only Mode](https://developers.cloudflare.com/dns/manage-dns-records/reference/proxied-dns-records/)
- [Privacy-Focused Alternatives](https://github.com/pluja/awesome-privacy#dns)
