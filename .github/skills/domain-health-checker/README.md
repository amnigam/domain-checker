# Domain Health Checker — Agent Skill for VS Code (Windows)

An Agent Skill that checks whether a domain is safe by running WHOIS,
DNS record queries, and a VirusTotal reputation lookup.
All scripts use PowerShell — no Linux tools required.

## Installation

### Option A: Project-level (shared with your team)

Copy the `domain-health-checker` folder into your repository:

```powershell
# From your project root
New-Item -ItemType Directory -Path ".github\skills" -Force
Copy-Item -Recurse domain-health-checker ".github\skills\domain-health-checker"
```

### Option B: Personal (available across all your projects)

```powershell
New-Item -ItemType Directory -Path "$HOME\.copilot\skills" -Force
Copy-Item -Recurse domain-health-checker "$HOME\.copilot\skills\domain-health-checker"
```

### Verify

1. Open VS Code and open the Copilot Chat panel
2. Switch to **Agent mode** (dropdown at the bottom of the chat panel)
3. Type `/skills` — you should see `domain-health-checker` in the list

## Prerequisites

| Tool              | Included with         | Notes                                      |
|-------------------|-----------------------|--------------------------------------------|
| `Resolve-DnsName` | Windows PowerShell 5+ | Built-in, no install needed                |
| `Invoke-RestMethod`| Windows PowerShell 5+| Built-in, no install needed                |
| `whois` (optional)| —                     | `winget install Sysinternals.Whois`        |

### VirusTotal API Key (optional but recommended)

1. Sign up free at https://www.virustotal.com/gui/join
2. Copy your API key from your profile page
3. Set it in PowerShell:
   ```powershell
   # Temporary (current session only)
   $env:VT_API_KEY = "your-api-key-here"

   # Permanent (persists across sessions)
   [System.Environment]::SetEnvironmentVariable("VT_API_KEY", "your-api-key-here", "User")
   ```

If no key is set, the skill will still run WHOIS and DNS checks but skip VirusTotal.

## Usage

Open Copilot Chat in Agent mode and try any of these prompts:

```
check the domain example.com
```

```
is suspicious-site.xyz safe?
```

```
run a domain health check on acme-corp.com
```

```
domain security audit for mycompany.io
```

The skill will automatically activate, run all three checks, and produce
a summary report with a verdict of SAFE, CAUTION, or MALICIOUS.

## File Structure

```
domain-health-checker/
├── SKILL.md                          # Skill instructions (read by the agent)
├── README.md                         # This file (for humans)
└── scripts/
    ├── whois_lookup.ps1              # Step 1: WHOIS via RDAP API or Sysinternals
    ├── dns_check.ps1                 # Step 2: NS, SPF, DMARC, DKIM via Resolve-DnsName
    └── virustotal_check.ps1          # Step 3: VirusTotal API reputation
```

## Differences from Linux/macOS Version

| Feature        | Linux/macOS version          | Windows version (this one)             |
|----------------|------------------------------|----------------------------------------|
| Shell          | Bash (`.sh`)                 | PowerShell (`.ps1`)                    |
| DNS queries    | `dig` (requires `dnsutils`)  | `Resolve-DnsName` (built-in)           |
| WHOIS          | `whois` command              | RDAP web API fallback + optional `whois.exe` |
| HTTP calls     | `curl`                       | `Invoke-RestMethod` (built-in)         |

The Windows version requires **zero extra installations** for DNS and VirusTotal checks.
