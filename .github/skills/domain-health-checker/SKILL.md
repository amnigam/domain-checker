---
name: domain-health-checker
description: >
  Checks the health and safety of a domain by running WHOIS lookups,
  DNS record queries (NS, SPF, DMARC, DKIM), and a VirusTotal reputation
  check. Use this skill when the user asks to "check a domain", "is this
  domain safe", "domain health check", "verify domain reputation",
  "check DNS records", "is this domain malicious", "domain security audit",
  or any variation of analyzing whether a domain is trustworthy.
---

# Domain Health Checker

Perform a three-step domain health and safety assessment.
After all three steps, synthesize findings into a verdict.

## Output File

All analysis results and the final report should be saved to `output.txt` in the workspace root directory.
This allows users to review the complete assessment and share findings easily.

## Prerequisites

This skill uses PowerShell scripts. All commands use `Resolve-DnsName`
(built into Windows) and `Invoke-RestMethod` (built into PowerShell 5.1+).
No extra tools need to be installed for DNS or VirusTotal checks.

For the WHOIS step, the script uses the public RDAP API as a fallback.
For better results, optionally install Sysinternals whois:

```powershell
winget install Sysinternals.Whois
```

The VirusTotal step requires a free API key. If the user has not provided one,
ask them to sign up at https://www.virustotal.com/gui/join and set the
environment variable:

```powershell
$env:VT_API_KEY = "your-key-here"
```

If no key is available, skip the VirusTotal step and note it in the report.

## Step 1: WHOIS Lookup

Run the helper script to fetch domain registration details and append to output.txt:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>/whois_lookup.ps1" <domain> *>&1 | Out-File -FilePath "output.txt" -Encoding utf8 -Append
```

From the output, extract and report:
- Registrar name
- Creation date and expiry date
- Domain age (calculate from creation date to today)
- Registrant organization and country (if available)
- Status flags (e.g. `clientTransferProhibited`)

**Red flags to watch for:**
- Domain is less than 30 days old — newly registered domains are higher risk
- Registrant details are entirely redacted with no organization — suspicious for business domains
- Domain is expired or in `pendingDelete` / `redemptionPeriod` status

## Step 2: DNS Record Queries

Run the helper script to query NS, SPF, DMARC, and DKIM records and append to output.txt:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>/dns_check.ps1" <domain> *>&1 | Out-File -FilePath "output.txt" -Encoding utf8 -Append
```

If the script is unavailable, run these queries manually in PowerShell:

```powershell
Resolve-DnsName -Name <domain> -Type NS
Resolve-DnsName -Name <domain> -Type TXT              # look for v=spf1
Resolve-DnsName -Name _dmarc.<domain> -Type TXT        # look for v=DMARC1
Resolve-DnsName -Name default._domainkey.<domain> -Type TXT  # DKIM
```

For each record type, assess:

| Record | Present & valid | Missing or misconfigured |
|--------|----------------|--------------------------|
| NS     | At least 2 nameservers from a reputable provider | Single NS or unknown/free DNS provider |
| SPF    | Contains `v=spf1` with explicit mechanisms and ends with `-all` or `~all` | Missing entirely, or uses `+all` (allows anyone to spoof) |
| DMARC  | Contains `v=DMARC1` with `p=reject` or `p=quarantine` | Missing, or `p=none` with no `rua` reporting URI |
| DKIM   | A valid TXT record under `<selector>._domainkey.<domain>` | Missing (try selectors: `default`, `google`, `selector1`, `selector2`, `k1`) |

**Red flags:**
- No SPF record at all — domain can be freely spoofed
- SPF with `+all` — effectively disables SPF protection
- No DMARC record — no policy for handling spoofed mail
- DMARC with `p=none` and no reporting — provides no protection

## Step 3: VirusTotal Reputation Check

Run the helper script to query the VirusTotal API and append to output.txt:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>/virustotal_check.ps1" <domain> *>&1 | Out-File -FilePath "output.txt" -Encoding utf8 -Append
```

If the `VT_API_KEY` environment variable is not set, skip this step and
note in the report that the VirusTotal check was skipped.

From the API response, extract:
- Number of engines that flagged the domain as malicious
- Number of engines that flagged it as suspicious
- Total number of engines that scanned
- Categories assigned by security vendors
- Any notable detections (name the vendors that flagged it)

**Red flags:**
- 1 or more engines flag the domain as **malicious**
- 3 or more engines flag the domain as **suspicious**
- Domain is categorized as phishing, malware, or spam by any vendor

## Step 4: Synthesize Verdict

After completing all three steps, produce a final report using this template and save it to output.txt.
Before starting the assessment, clear any existing output.txt file.

To initialize the output file at the beginning:
```powershell
New-Item "output.txt" -ItemType File -Force | Out-Null
```

Template for the final report:

```
# Domain Health Report: <domain>

## Summary
| Check          | Status |
|----------------|--------|
| WHOIS          | ✅ Clean / ⚠️ Warning / ❌ Suspicious |
| DNS Records    | ✅ Clean / ⚠️ Warning / ❌ Suspicious |
| VirusTotal     | ✅ Clean / ⚠️ Warning / ❌ Malicious / ⏭️ Skipped |

## Overall Verdict: ✅ SAFE / ⚠️ CAUTION / ❌ MALICIOUS

## Details

### WHOIS
<findings from Step 1>

### DNS Records
<findings from Step 2>

### VirusTotal
<findings from Step 3>

### Recommendations
<actionable advice based on findings>
```

After generating the final report above, append it to output.txt:
```powershell
$report | Out-File -FilePath "output.txt" -Encoding utf8 -Append
```

Inform the user that the complete analysis has been saved to output.txt.

**Verdict logic:**
- **❌ MALICIOUS** — VirusTotal flags the domain as malicious, OR domain age < 7 days AND DNS records are entirely missing.
- **⚠️ CAUTION** — Domain age < 30 days, OR SPF/DMARC are missing or misconfigured, OR VirusTotal shows suspicious flags.
- **✅ SAFE** — Domain is well-established, DNS records are properly configured, and VirusTotal shows no detections.
