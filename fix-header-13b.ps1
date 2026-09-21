$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$header = Join-Path $root "components\Header.tsx"
$lib = Join-Path $root "lib\projects.ts"
if (-not (Test-Path -LiteralPath $header)) { Write-Host "NOT FOUND components\Header.tsx"; exit 1 }
if (-not (Test-Path -LiteralPath $lib)) { Write-Host "NOT FOUND lib\projects.ts"; exit 1 }

$hit = Select-String -LiteralPath $lib -Pattern "export\s+(async\s+)?function\s+getProjects" | Select-Object -First 1
if ($hit) { Write-Host ("FOUND: " + $hit.Line.Trim()) } else { Write-Host "WARNING: no 'export function getProjects' in lib\projects.ts - send me: Select-String -LiteralPath .\lib\projects.ts -Pattern getProjects" }

$bakDir = Join-Path $root "_backups"
if (-not (Test-Path -LiteralPath $bakDir)) { New-Item -ItemType Directory -Path $bakDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $header -Destination (Join-Path $bakDir ("Header.tsx." + $stamp + ".bak"))

$old = @'
  const all = await getProjects();
  const items = all.map((p) => ({
    name: String(p.name || ""),
    slug: String(p.slug || ""),
    chain: String(p.chain || ""),
    logo: String(p.logo || ""),
  }));
'@

$new = @'
  const all = (await Promise.resolve(getProjects())) as unknown as Array<Record<string, unknown>>;
  const items = all
    .map((p) => ({
      name: String(p.name ?? ""),
      slug: String(p.slug ?? ""),
      chain: String(p.chain ?? ""),
      logo: String(p.logo ?? ""),
    }))
    .filter((x) => x.name && x.slug);
'@

$text = [System.IO.File]::ReadAllText($header, $utf8).Replace("`r`n", "`n")
$oldN = $old.Replace("`r`n", "`n")
$newN = $new.Replace("`r`n", "`n")

if ($text.Contains("Promise.resolve(getProjects())")) {
  Write-Host "SKIP: Header.tsx already patched"
} elseif (-not $text.Contains($oldN)) {
  Write-Host "NOT FOUND items block in Header.tsx - send me: Get-Content -LiteralPath .\components\Header.tsx"
  exit 1
} else {
  $text = $text.Replace($oldN, $newN).Replace("`n", "`r`n")
  [System.IO.File]::WriteAllText($header, $text, $utf8)
  Write-Host "OK: Header.tsx patched"
}