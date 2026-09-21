# redesign-cryptorank-9e.ps1 (social images: WebP logos + small logo files)
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File .\redesign-cryptorank-9e.ps1
#
# Patches lib\og.tsx: toDataUri() now converts every logo (WebP, PNG, JPEG) with `sharp`
# into a PNG of at most 256x256. If sharp is missing or the image cannot be read, the old
# behaviour is used (raw PNG/JPEG, otherwise initials are drawn).
# Requires the sharp package: npm install sharp
# Backup: lib\og.tsx.bak-redesign9e
# NOTE: ASCII-only on purpose.

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$file = '.\lib\og.tsx'
if (-not (Test-Path -LiteralPath $file)) {
  Write-Host "File $file not found. Run this from the project root." -ForegroundColor Red
  exit 1
}

if (-not (Test-Path -LiteralPath '.\node_modules\sharp')) {
  Write-Host 'The sharp package is not installed. Run this first, then start the script again:' -ForegroundColor Yellow
  Write-Host '  npm install sharp'
  exit 1
}

$path = (Resolve-Path -LiteralPath $file).Path
$src = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)

if ($src.Contains('sharp')) {
  Write-Host 'Already applied (sharp found in lib\og.tsx). Nothing to do.' -ForegroundColor Green
  exit 0
}

$m = [regex]::Match($src, '(?s)function toDataUri\(buf: Buffer\): string \| null \{.*?\r?\n\}')
if (-not $m.Success) {
  Write-Host 'NOT FOUND: function toDataUri in lib\og.tsx' -ForegroundColor Yellow
  exit 1
}

$new = @'
async function toDataUri(buf: Buffer): Promise<string | null> {
  // Preferred: re-encode as a small PNG. This also makes WebP logos work.
  try {
    const sharp = (await import("sharp")).default;
    const out = await sharp(buf)
      .resize(256, 256, { fit: "inside", withoutEnlargement: true })
      .png()
      .toBuffer();
    return "data:image/png;base64," + out.toString("base64");
  } catch {
    // sharp missing or the image cannot be read: fall back to raw PNG/JPEG below.
  }

  if (buf.length > 1500000) return null;
  const type = sniff(buf);
  return type ? "data:" + type + ";base64," + buf.toString("base64") : null;
}
'@

$s = $src.Replace($m.Value, $new.TrimEnd())

Copy-Item -LiteralPath $path "${path}.bak-redesign9e"
[System.IO.File]::WriteAllText($path, $s, $utf8)

Write-Host 'lib\og.tsx updated.' -ForegroundColor Green
Write-Host 'Restart the dev server (Ctrl+C, npm run dev) and open /project/baibai/opengraph-image:' -ForegroundColor Green
Write-Host '  the BaiBai logo should now replace the BA initials.'
