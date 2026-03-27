# Domain Checker

A PowerShell-based toolkit to assess the health, safety, and reputation of any domain. It performs WHOIS lookups, DNS record analysis (NS, SPF, DMARC, DKIM), and VirusTotal reputation checks, synthesizing the results into a clear verdict.

## Features
- **WHOIS Lookup:** Fetches registrar, creation/expiry dates, domain age, and status.
- **DNS Record Analysis:** Checks for NS, SPF, DMARC, and DKIM records and flags misconfigurations.
- **VirusTotal Reputation:** Queries VirusTotal for security vendor flags and reputation.
- **Automated Report:** Combines all findings into a human-readable report and saves it to `output.txt`.

## Prerequisites
- Windows with PowerShell 5.1+
- Internet access for WHOIS API and VirusTotal
- (Optional) [Sysinternals Whois](https://docs.microsoft.com/en-us/sysinternals/downloads/whois) for more detailed WHOIS

## Setup
1. **Clone the repository:**
   ```sh
   git clone <repo-url>
   cd domain-checker
   ```
2. **(Optional) Install Sysinternals Whois:**
   ```sh
   winget install Sysinternals.Whois
   ```
3. **Set your VirusTotal API key:**
   - Get a free key at https://www.virustotal.com/gui/join
   - Set it in your session:
     ```powershell
     $env:VT_API_KEY = "your-key-here"
     ```

## Usage
Run the three scripts in order, replacing `<domain>` with the domain you want to check:

```powershell
# Clear previous output
New-Item "output.txt" -ItemType File -Force | Out-Null

# WHOIS
powershell -ExecutionPolicy Bypass -File .github/skills/domain-health-checker/whois_lookup.ps1 <domain> *>&1 | Out-File -FilePath "output.txt" -Encoding utf8 -Append

# DNS
powershell -ExecutionPolicy Bypass -File .github/skills/domain-health-checker/dns_check.ps1 <domain> *>&1 | Out-File -FilePath "output.txt" -Encoding utf8 -Append

# VirusTotal
powershell -ExecutionPolicy Bypass -File .github/skills/domain-health-checker/virustotal_check.ps1 <domain> *>&1 | Out-File -FilePath "output.txt" -Encoding utf8 -Append
```

## Output
- All results and the final report are saved in `output.txt` in the project root.
- Open `output.txt` in VS Code or any UTF-8 compatible editor to view the full analysis.

## Example
```
powershell -ExecutionPolicy Bypass -File .github/skills/domain-health-checker/whois_lookup.ps1 example.com *>&1 | Out-File -FilePath "output.txt" -Encoding utf8 -Append
```

## License
MIT

## Credits
- [Sysinternals Whois](https://docs.microsoft.com/en-us/sysinternals/downloads/whois)
- [VirusTotal](https://www.virustotal.com/)
