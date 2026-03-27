# virustotal_check.ps1 - Query VirusTotal API for domain reputation
# Usage: powershell -ExecutionPolicy Bypass -File virustotal_check.ps1 <domain>
# Requires: VT_API_KEY environment variable (free key from virustotal.com)

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Domain
)

$ErrorActionPreference = "Stop"

# Strip protocol and path if the user passed a URL
$Domain = $Domain -replace '^https?://', '' -replace '/.*', '' -replace '^www\.', ''

Write-Host "============================================"
Write-Host "  VirusTotal Reputation: $Domain"
Write-Host "============================================"
Write-Host ""

# Check for API key
$apiKey = $env:VT_API_KEY
if (-not $apiKey) {
    Write-Host "ERROR: VT_API_KEY environment variable is not set."
    Write-Host ""
    Write-Host "To get a free API key:"
    Write-Host "  1. Sign up at https://www.virustotal.com/gui/join"
    Write-Host "  2. Go to your profile -> API Key"
    Write-Host '  3. Set it: $env:VT_API_KEY = "your-key-here"'
    Write-Host "     Or permanently: [System.Environment]::SetEnvironmentVariable('VT_API_KEY','your-key-here','User')"
    exit 1
}

# Query VirusTotal API v3
try {
    $headers = @{ "x-apikey" = $apiKey }
    $uri = "https://www.virustotal.com/api/v3/domains/$Domain"

    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 15
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404) {
        Write-Host "Domain not found in VirusTotal database."
    }
    elseif ($statusCode -eq 401) {
        Write-Host "ERROR: Invalid API key. Check your VT_API_KEY."
    }
    elseif ($statusCode -eq 429) {
        Write-Host "ERROR: Rate limit exceeded. Free keys allow 4 requests/minute."
    }
    else {
        Write-Host "ERROR: API request failed - $_"
    }
    exit 1
}

# Extract analysis stats
$stats = $response.data.attributes.last_analysis_stats
$malicious  = if ($stats.malicious)  { $stats.malicious }  else { 0 }
$suspicious = if ($stats.suspicious) { $stats.suspicious } else { 0 }
$harmless   = if ($stats.harmless)   { $stats.harmless }   else { 0 }
$undetected = if ($stats.undetected) { $stats.undetected } else { 0 }
$total = $malicious + $suspicious + $harmless + $undetected

Write-Host "--- Analysis Stats ---"
Write-Host "Malicious:  $malicious"
Write-Host "Suspicious: $suspicious"
Write-Host "Harmless:   $harmless"
Write-Host "Undetected: $undetected"
Write-Host "Total engines scanned: $total"
Write-Host ""

# Quick assessment
if ($malicious -gt 0) {
    Write-Host "[X] MALICIOUS - $malicious engine(s) flagged this domain"
}
elseif ($suspicious -ge 3) {
    Write-Host "[!] SUSPICIOUS - $suspicious engine(s) flagged this domain as suspicious"
}
elseif ($suspicious -gt 0) {
    Write-Host "[!] LOW RISK - $suspicious engine(s) flagged as suspicious (below threshold)"
}
else {
    Write-Host "[OK] CLEAN - no engines flagged this domain"
}

Write-Host ""

# Reputation score
$reputation = $response.data.attributes.reputation
if ($null -ne $reputation) {
    Write-Host "Reputation score: $reputation"
}

# Categories
Write-Host ""
Write-Host "--- Vendor Categories ---"
$categories = $response.data.attributes.categories
if ($categories) {
    $categoryProps = $categories | Get-Member -MemberType NoteProperty
    $count = 0
    foreach ($prop in $categoryProps) {
        if ($count -ge 10) { break }
        Write-Host "  $($prop.Name): $($categories.$($prop.Name))"
        $count++
    }
}
else {
    Write-Host "(no categories available)"
}

# Specific vendor detections
Write-Host ""
Write-Host "--- Flagged Detections ---"
$results = $response.data.attributes.last_analysis_results
if ($results) {
    $flagged = $results | Get-Member -MemberType NoteProperty |
        Where-Object {
            $r = $results.$($_.Name)
            $r.category -eq "malicious" -or $r.category -eq "suspicious"
        }
    if ($flagged) {
        foreach ($f in $flagged | Select-Object -First 15) {
            $det = $results.$($f.Name)
            Write-Host "  $($f.Name): $($det.category) - $($det.result)"
        }
    }
    else {
        Write-Host "  (no vendors flagged this domain)"
    }
}

Write-Host ""
Write-Host "Full report: https://www.virustotal.com/gui/domain/$Domain"
Write-Host ""
Write-Host "============================================"
Write-Host "  VirusTotal check complete."
Write-Host "============================================"
