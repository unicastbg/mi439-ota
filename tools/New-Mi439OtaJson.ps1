param(
    [Parameter(Mandatory = $true)]
    [string] $ZipPath,

    [Parameter(Mandatory = $true)]
    [string] $DownloadUrl,

    [string] $OutputPath = ".\docs\Mi439-23.2.json",

    [string] $BuildType,

    [string] $Version,

    [string] $Device = "Mi439"
)

$ErrorActionPreference = "Stop"

function Read-OtaMetadata {
    param([string] $Path)

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq "META-INF/com/android/metadata" } | Select-Object -First 1
        if (-not $entry) {
            return @{}
        }

        $reader = New-Object System.IO.StreamReader($entry.Open())
        try {
            $content = $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    } finally {
        $zip.Dispose()
    }

    $metadata = @{}
    foreach ($line in ($content -split "`r?`n")) {
        if ($line -match "^\s*([^=]+)=(.*)$") {
            $metadata[$matches[1]] = $matches[2]
        }
    }

    return $metadata
}

function Get-FilenameParts {
    param([string] $Filename)

    $base = [System.IO.Path]::GetFileNameWithoutExtension($Filename)
    $parts = $base -split "-"

    if ($parts.Count -lt 5 -or $parts[0] -ne "lineage") {
        throw "Expected a LineageOS filename like lineage-23.2-YYYYMMDD-UNOFFICIAL-Mi439-signed.zip, got $Filename"
    }

    return @{
        Version = $parts[1]
        Date = $parts[2]
        Type = $parts[3]
        Device = $parts[4]
    }
}

$resolvedZip = Resolve-Path -LiteralPath $ZipPath
$item = Get-Item -LiteralPath $resolvedZip
$filename = $item.Name
$parts = Get-FilenameParts -Filename $filename
$metadata = Read-OtaMetadata -Path $item.FullName

if (-not $Version) {
    $Version = $parts.Version
}

if (-not $BuildType) {
    $BuildType = $parts.Type
}

if ($parts.Device -ne $Device) {
    Write-Warning "Filename device '$($parts.Device)' does not match requested device '$Device'."
}

$timestamp = $null
if ($metadata.ContainsKey("post-timestamp") -and $metadata["post-timestamp"]) {
    $timestamp = [int64] $metadata["post-timestamp"]
} else {
    $date = [datetime]::ParseExact($parts.Date, "yyyyMMdd", [Globalization.CultureInfo]::InvariantCulture)
    $timestamp = [int64] ([DateTimeOffset]::new($date, [TimeSpan]::Zero).ToUnixTimeSeconds())
}

$file = [ordered] @{
    filename = $filename
    sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    size = $item.Length
    url = $DownloadUrl
}

if ($metadata.ContainsKey("post-security-patch-level") -and $metadata["post-security-patch-level"]) {
    $file.os_patch_level = $metadata["post-security-patch-level"]
}

if ($metadata.ContainsKey("post-sdk-level") -and $metadata["post-sdk-level"]) {
    $file.os_sdk_level = [int] $metadata["post-sdk-level"]
}

if ($metadata.ContainsKey("ota-property-files") -and $metadata["ota-property-files"]) {
    $file.ota_property_files = $metadata["ota-property-files"]
}

$update = [ordered] @{
    datetime = $timestamp
    files = @($file)
    type = $BuildType
    version = $Version
}

$output = ConvertTo-Json -InputObject @($update) -Depth 8
$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Set-Content -LiteralPath $OutputPath -Value $output -Encoding utf8
Write-Host "Wrote $OutputPath"
Write-Host "Updater endpoint should serve this file over HTTPS."
