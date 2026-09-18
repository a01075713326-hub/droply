$root = "C:\Users\Sasa\Desktop\zip"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Patch-File {
    param([string]$Path, [string]$Old, [string]$New, [string]$Label)
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $count = ([regex]::Matches($content, [regex]::Escape($Old))).Count
    if ($count -eq 0) {
        Write-Host "SKIP ($Label): old string not found" -ForegroundColor Yellow
        return
    }
    if ($count -gt 1) {
        Write-Host "SKIP ($Label): found $count times, not unique" -ForegroundColor Yellow
        return
    }
    $updated = $content.Replace($Old, $New)
    [System.IO.File]::WriteAllText($Path, $updated, $utf8NoBom)
    Write-Host "OK ($Label)"
}

$cssPath = Join-Path $root "app\globals.css"

# 1. Add Inter font import at the very top
Patch-File -Path $cssPath -Label "Inter import" `
  -Old '*{box-sizing:border-box}' `
  -New "@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');*{box-sizing:border-box}"

# 2. Switch body font-family to Inter first
Patch-File -Path $cssPath -Label "body font-family" `
  -Old 'font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display","SF Pro Text","Segoe UI",Roboto,Helvetica,Arial,sans-serif;min-height:100vh' `
  -New 'font-family:''Inter'',-apple-system,BlinkMacSystemFont,"SF Pro Display","SF Pro Text","Segoe UI",Roboto,Helvetica,Arial,sans-serif;min-height:100vh'

# 3. Bump small text sizes (the ones you asked about + related ones)
Patch-File -Path $cssPath -Label "type-pill/status-pill" `
  -Old '.type-pill,.status-pill{display:inline-block;border-radius:7px;padding:5px 8px;font-size:11px;border:1px solid rgba(255,255,255,.1);width:max-content}' `
  -New '.type-pill,.status-pill{display:inline-block;border-radius:7px;padding:5px 9px;font-size:12px;font-weight:600;border:1px solid rgba(255,255,255,.1);width:max-content}'

Patch-File -Path $cssPath -Label "table-head" `
  -Old '.table-head{padding:14px 15px;color:#606c7e;text-transform:uppercase;font-size:11px;letter-spacing:.6px}' `
  -New '.table-head{padding:14px 15px;color:#606c7e;text-transform:uppercase;font-size:12px;letter-spacing:.6px}'

Patch-File -Path $cssPath -Label "metrics-grid span" `
  -Old '.metrics-grid span{display:block;color:#697587;font-size:11px;letter-spacing:1px}' `
  -New '.metrics-grid span{display:block;color:#697587;font-size:12px;letter-spacing:1px}'

Patch-File -Path $cssPath -Label "section-kicker" `
  -Old '.section-kicker{font-size:10px;color:#78869a;letter-spacing:1.1px;display:flex;align-items:center;gap:7px}' `
  -New '.section-kicker{font-size:11px;color:#78869a;letter-spacing:1.1px;display:flex;align-items:center;gap:7px}'

Patch-File -Path $cssPath -Label "footer" `
  -Old '.footer{border-top:1px solid rgba(255,255,255,.08);min-height:105px;display:flex;align-items:center;gap:12px;color:#667285;font-size:10px;position:relative}' `
  -New '.footer{border-top:1px solid rgba(255,255,255,.08);min-height:105px;display:flex;align-items:center;gap:12px;color:#667285;font-size:11px;position:relative}'

Patch-File -Path $cssPath -Label "event-card p" `
  -Old '.event-card p{margin:5px 0 0;color:#6f7b8d;font-size:10px}' `
  -New '.event-card p{margin:5px 0 0;color:#6f7b8d;font-size:11px}'

Patch-File -Path $cssPath -Label "mini-event small" `
  -Old '.mini-event small{display:block;color:#687486;font-size:11px;margin-top:2px}' `
  -New '.mini-event small{display:block;color:#687486;font-size:12px;margin-top:2px}'

Patch-File -Path $cssPath -Label "mini-event span" `
  -Old '.mini-event>span{font-size:11px;color:#6e7c90}' `
  -New '.mini-event>span{font-size:12px;color:#6e7c90}'

Patch-File -Path $cssPath -Label "network-card b" `
  -Old '.network-card b{display:block;font-size:10px}' `
  -New '.network-card b{display:block;font-size:11px}'

Patch-File -Path $cssPath -Label "network-card small" `
  -Old '.network-card small{display:block;color:#657083;font-size:11px;margin-top:3px}' `
  -New '.network-card small{display:block;color:#657083;font-size:12px;margin-top:3px}'

Patch-File -Path $cssPath -Label "chain-row small" `
  -Old '.chain-row small{color:#697587;font-size:11px}' `
  -New '.chain-row small{color:#697587;font-size:12px}'

Patch-File -Path $cssPath -Label "project-cell small" `
  -Old '.project-cell small{display:block;color:#697487;font-size:11px;margin-top:3px}' `
  -New '.project-cell small{display:block;color:#697487;font-size:12px;margin-top:3px}'

Write-Host ""
Write-Host "Done. Refresh browser (Ctrl+Shift+R for full font reload) and check the site."