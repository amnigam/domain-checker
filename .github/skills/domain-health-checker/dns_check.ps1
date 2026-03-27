# dns_check.ps1 - Query NS, SPF, DMARC, and DKIM records for a domain
# Usage: powershell -ExecutionPolicy Bypass -File dns_check.ps1 <domain>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Domain
)

$ErrorActionPreference = "Continue"

# Strip protocol and path if the user passed a URL
$Domain = $Domain -replace '^https?://', '' -replace '/.*', '' -replace '^www\.', ''

Write-Host "============================================"
Write-Host "  DNS Record Check: $Domain"
Write-Host "============================================"

# --- NS Records ---
Write-Host ""
Write-Host "--- NS Records ---"
try {
    $nsRecords = Resolve-DnsName -Name $Domain -Type NS -ErrorAction Stop |
        Where-Object { $_.QueryType -eq "NS" }
    if ($nsRecords) {
        foreach ($ns in $nsRecords) {
            Write-Host "  $($ns.NameHost)"
        }
        if ($nsRecords.Count -ge 2) {
            Write-Host "[OK] $($nsRecords.Count) nameservers found"
        } else {
            Write-Host "[!] Only $($nsRecords.Count) nameserver found - at least 2 recommended"
        }
    } else {
        Write-Host "(no NS records found)"
    }
}
catch {
    Write-Host "(no NS records found - $_)"
}

# --- SPF Record ---
Write-Host ""
Write-Host "--- SPF Record (TXT on $Domain) ---"
$spfFound = $false
try {
    $txtRecords = Resolve-DnsName -Name $Domain -Type TXT -ErrorAction Stop |
        Where-Object { $_.QueryType -eq "TXT" }
    foreach ($txt in $txtRecords) {
        $value = $txt.Strings -join ""
        if ($value -match "v=spf1") {
            Write-Host "  $value"
            $spfFound = $true

            if ($value -match "\+all") {
                Write-Host "[!] WARNING: SPF uses '+all' - allows ANY server to send as $Domain"
            }
            elseif ($value -match "-all") {
                Write-Host "[OK] SPF ends with '-all' (hard fail) - good"
            }
            elseif ($value -match "~all") {
                Write-Host "[!] SPF ends with '~all' (soft fail) - acceptable but '-all' is stronger"
            }
        }
    }
}
catch {
    # Resolve-DnsName may throw on NXDOMAIN
}
if (-not $spfFound) {
    Write-Host "(no SPF record found)"
    Write-Host "[X] Missing SPF - this domain can be spoofed by anyone"
}

# --- DMARC Record ---
Write-Host ""
Write-Host "--- DMARC Record (TXT on _dmarc.$Domain) ---"
$dmarcFound = $false
try {
    $dmarcRecords = Resolve-DnsName -Name "_dmarc.$Domain" -Type TXT -ErrorAction Stop |
        Where-Object { $_.QueryType -eq "TXT" }
    foreach ($txt in $dmarcRecords) {
        $value = $txt.Strings -join ""
        if ($value -match "v=DMARC1") {
            Write-Host "  $value"
            $dmarcFound = $true

            if ($value -match "p=reject") {
                Write-Host "[OK] DMARC policy is 'reject' - strongest protection"
            }
            elseif ($value -match "p=quarantine") {
                Write-Host "[OK] DMARC policy is 'quarantine' - good protection"
            }
            elseif ($value -match "p=none") {
                Write-Host "[!] DMARC policy is 'none' - monitoring only, no enforcement"
            }
        }
    }
}
catch {
    # NXDOMAIN is expected if no DMARC record exists
}
if (-not $dmarcFound) {
    Write-Host "(no DMARC record found)"
    Write-Host "[X] Missing DMARC - no email authentication policy"
}

# --- DKIM Record ---
Write-Host ""
Write-Host "--- DKIM Record (trying common selectors) ---"
$dkimFound = $false
$selectors = @("default", "google", "selector1", "selector2", "k1", "dkim", "mail", "s1", "s2")

foreach ($sel in $selectors) {
    $dkimDomain = "$sel._domainkey.$Domain"
    try {
        $dkimRecords = Resolve-DnsName -Name $dkimDomain -Type TXT -ErrorAction Stop |
            Where-Object { $_.QueryType -eq "TXT" }
        if ($dkimRecords) {
            $value = ($dkimRecords[0].Strings -join "")
            if ($value -and $value.Length -gt 5) {
                Write-Host "  Selector '$sel': $value"
                $dkimFound = $true
                break
            }
        }
    }
    catch {
        # NXDOMAIN — this selector doesn't exist, try next
    }
}

if (-not $dkimFound) {
    $selectorList = $selectors -join ", "
    Write-Host "(no DKIM record found with common selectors: $selectorList)"
    Write-Host "[!] DKIM not found - the domain may use a non-standard selector"
}

Write-Host ""
Write-Host "============================================"
Write-Host "  DNS check complete."
Write-Host "============================================"
