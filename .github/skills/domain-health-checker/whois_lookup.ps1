# whois_lookup.ps1 - Fetch and display WHOIS information for a domain
# Usage: powershell -ExecutionPolicy Bypass -File whois_lookup.ps1 <domain>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Domain
)

$ErrorActionPreference = "Stop"

# Strip protocol and path if the user passed a URL
$Domain = $Domain -replace '^https?://', '' -replace '/.*', '' -replace '^www\.', ''

Write-Host "============================================"
Write-Host "  WHOIS Lookup: $Domain"
Write-Host "============================================"
Write-Host ""

# Try whois.exe if available (e.g. Sysinternals whois), otherwise use web API
$whoisCmd = Get-Command whois -ErrorAction SilentlyContinue

if ($whoisCmd) {
    Write-Host "Using local whois command..."
    Write-Host ""
    try {
        $output = & whois $Domain 2>&1
        $output | Select-String -Pattern "Registrar|Creation Date|Expir|Updated Date|Registrant Org|Registrant Country|Domain Status|Name Server|Registrant Name" -CaseSensitive:$false |
            Select-Object -First 30 |
            ForEach-Object { Write-Host $_.Line }

        Write-Host ""
        Write-Host "--- Raw WHOIS (first 60 lines) ---"
        $output | Select-Object -First 60 | ForEach-Object { Write-Host $_ }
    }
    catch {
        Write-Host "ERROR: whois command failed: $_"
    }
}
else {
    # Fallback: use a public WHOIS API
    Write-Host "Local 'whois' not found. Using web API fallback..."
    Write-Host "(Install Sysinternals whois: winget install Sysinternals.Whois)"
    Write-Host ""

    try {
        # Use RDAP (Registration Data Access Protocol) — the modern replacement for WHOIS
        $rdapUrl = "https://rdap.org/domain/$Domain"
        $response = Invoke-RestMethod -Uri $rdapUrl -Method Get -TimeoutSec 15 -ErrorAction Stop

        # Extract key fields
        if ($response.name)        { Write-Host "Domain:       $($response.name)" }
        if ($response.handle)      { Write-Host "Handle:       $($response.handle)" }

        # Registrar
        $registrar = $response.entities | Where-Object { $_.roles -contains "registrar" }
        if ($registrar) {
            $regName = $registrar.vcardArray[1] | Where-Object { $_[0] -eq "fn" } | ForEach-Object { $_[3] }
            if ($regName) { Write-Host "Registrar:    $regName" }
        }

        # Dates
        foreach ($event in $response.events) {
            switch ($event.eventAction) {
                "registration"    { Write-Host "Created:      $($event.eventDate)" }
                "expiration"      { Write-Host "Expires:      $($event.eventDate)" }
                "last changed"    { Write-Host "Updated:      $($event.eventDate)" }
            }
        }

        # Status
        if ($response.status) {
            Write-Host "Status:       $($response.status -join ', ')"
        }

        # Nameservers
        if ($response.nameservers) {
            Write-Host ""
            Write-Host "Nameservers:"
            foreach ($ns in $response.nameservers) {
                Write-Host "  $($ns.ldhName)"
            }
        }
    }
    catch {
        Write-Host "ERROR: Could not fetch WHOIS data via RDAP."
        Write-Host "Details: $_"
        Write-Host ""
        Write-Host "Alternatives:"
        Write-Host "  1. Install Sysinternals whois: winget install Sysinternals.Whois"
        Write-Host "  2. Check manually: https://who.is/whois/$Domain"
    }
}
