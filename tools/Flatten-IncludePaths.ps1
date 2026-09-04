<#
.SYNOPSIS
    Flattens relative include directives in a flat source tree.

.DESCRIPTION
    The deploy repository keeps every unit and every include side by side in a
    single folder, so the relative prefixes inherited from the nested
    development tree ({$I ../../ORM.Defines.inc}) no longer resolve. This script
    rewrites each include directive that carries a path prefix into its bare
    form ({$I ORM.Defines.inc}).

    Safety rules:
      * Only directives that occupy a whole line are rewritten. A directive
        quoted inside prose - a changelog entry describing a past fix, for
        instance - is left alone and reported separately, so documentation is
        never silently rewritten.
      * An include is only flattened when the target .inc actually exists in the
        target folder. Directives pointing at files shipped by external
        libraries (Synapse.Version.inc, ConexaoBanco.inc, ...) stay untouched.
      * The UTF-8 BOM is preserved per file: a file that has one keeps it, a
        file without one does not gain one.
      * Line endings are preserved byte for byte. The file is processed as a
        single string and only the text inside the directive is replaced, so
        CRLF never degrades to LF.
      * Idempotent: a second run reports zero changes.

.PARAMETER Path
    Folder holding the flattened sources. Defaults to the "src" folder beside
    this script's parent (the repository root).

.PARAMETER DryRun
    Report what would change without writing anything.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\Flatten-IncludePaths.ps1 -DryRun
    powershell -ExecutionPolicy Bypass -File tools\Flatten-IncludePaths.ps1
#>
[CmdletBinding()]
param(
    [string] $Path,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

if (-not $Path) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $Path = Join-Path $repoRoot 'src'
}

if (-not (Test-Path -LiteralPath $Path)) {
    throw "Target folder not found: $Path"
}
$Path = (Resolve-Path -LiteralPath $Path).Path

Write-Host "Target folder : $Path"
if ($DryRun) { Write-Host "Mode          : DRY RUN (no files written)" }
else         { Write-Host "Mode          : APPLY" }
Write-Host ''

# Include files available locally: only these may be flattened.
$localIncludes = @{}
foreach ($inc in Get-ChildItem -LiteralPath $Path -Filter '*.inc' -File) {
    $localIncludes[$inc.Name.ToLowerInvariant()] = $inc.Name
}
Write-Host "Local .inc files: $($localIncludes.Count)"

# A directive alone on its line. The lookahead keeps the CR of a CRLF pair out
# of the match, so line endings survive untouched.
$rxLine = '(?im)^([ \t]*)\{\$(I|INCLUDE)([ \t]+)([^}\r\n]*?[\\/])([A-Za-z0-9_.\-]+\.inc)([ \t]*)\}([ \t]*)(?=\r?$)'

# Same directive anywhere, used only to spot in-line mentions we deliberately skip.
$rxAny  = '(?i)\{\$(?:I|INCLUDE)[ \t]+[^}\r\n]*?[\\/][A-Za-z0-9_.\-]+\.inc[ \t]*\}'

$targets = Get-ChildItem -LiteralPath $Path -File |
           Where-Object { $_.Extension -match '^\.(pas|inc|dpr|dpk|lpr)$' }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$bom       = [byte[]](0xEF, 0xBB, 0xBF)

$changedFiles = 0
$totalHits    = 0
$byVariant    = @{}
$externals    = @{}
$inlineLeft   = @()

foreach ($file in $targets) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)

    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if ($hasBom) { $offset = 3 } else { $offset = 0 }
    $text = $utf8NoBom.GetString($bytes, $offset, $bytes.Length - $offset)

    $fileHits = 0

    $newText = [regex]::Replace($text, $rxLine, {
        param($m)

        $lead    = $m.Groups[1].Value   # indentation
        $keyword = $m.Groups[2].Value   # I or INCLUDE, as written
        $space   = $m.Groups[3].Value
        $prefix  = $m.Groups[4].Value   # ../ ..\ ../../ ...
        $name    = $m.Groups[5].Value
        $tail    = $m.Groups[6].Value
        $trail   = $m.Groups[7].Value

        if (-not $localIncludes.ContainsKey($name.ToLowerInvariant())) {
            # Not ours to flatten: shipped by an external library.
            $k = ('{$' + $keyword + $space + $prefix + $name + $tail + '}')
            $script:externals[$k] = [int]$script:externals[$k] + 1
            return $m.Value
        }

        $k = ('{$' + $keyword + $space + $prefix + $name + $tail + '}')
        $script:byVariant[$k] = [int]$script:byVariant[$k] + 1
        $script:fileHits++
        $script:totalHits++

        return ($lead + '{$' + $keyword + $space + $name + $tail + '}' + $trail)
    })

    # Anything still carrying a prefix after the rewrite is an in-line mention.
    foreach ($m in [regex]::Matches($newText, $rxAny)) {
        $inlineLeft += ("{0}: {1}" -f $file.Name, $m.Value)
    }

    if ($fileHits -gt 0) {
        $changedFiles++
        Write-Host ("  {0,-46} {1} include(s)" -f $file.Name, $fileHits)

        if (-not $DryRun) {
            $payload = $utf8NoBom.GetBytes($newText)
            if ($hasBom) { $payload = $bom + $payload }
            [System.IO.File]::WriteAllBytes($file.FullName, $payload)
        }
    }
}

Write-Host ''
Write-Host '=== Rewritten variants ==='
if ($byVariant.Count -eq 0) {
    Write-Host '  (none - nothing to flatten)'
} else {
    $byVariant.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host ("  {0,5}x  {1}" -f $_.Value, $_.Key)
    }
}

Write-Host ''
Write-Host '=== External includes left untouched (not present locally) ==='
if ($externals.Count -eq 0) {
    Write-Host '  (none)'
} else {
    $externals.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host ("  {0,5}x  {1}" -f $_.Value, $_.Key)
    }
}

Write-Host ''
Write-Host '=== In-line mentions left untouched (prose, not a directive) ==='
if ($inlineLeft.Count -eq 0) {
    Write-Host '  (none)'
} else {
    $inlineLeft | ForEach-Object { Write-Host ("  {0}" -f $_) }
}

Write-Host ''
Write-Host ("Files scanned : {0}" -f $targets.Count)
Write-Host ("Files changed : {0}" -f $changedFiles)
Write-Host ("Includes fixed: {0}" -f $totalHits)
if ($DryRun) { Write-Host 'DRY RUN - no file was written.' }