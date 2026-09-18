$path = ".\scripts\sync.js"

if (-not (Test-Path $path)) {
    Write-Host "Не найден файл: $path (запусти скрипт из корня проекта)" -ForegroundColor Red
    exit 1
}

Copy-Item $path "$path.bak" -Force
Write-Host "Бэкап создан: $path.bak" -ForegroundColor Yellow

$content = Get-Content -Raw -Path $path

$pattern = [regex]::new(
  '// --------------------------------------------------------\r?\n\s*// DATE\r?\n\s*// --------------------------------------------------------[\s\S]*?(?=// --------------------------------------------------------\r?\n\s*// FUNDING)',
  'Singleline'
)

$replacement = @'
// --------------------------------------------------------
      // DATE
      // --------------------------------------------------------

      // Scan every <li> (icons/tags inside are fine, we strip them),
      // look for one that mentions a date-ish keyword AND contains
      // an ISO-like date (YYYY-MM-DD / YYYY.MM.DD / YYYY/MM/DD).
      const liPattern = /<li[^>]*>([\s\S]*?)<\/li>/gi;
      const dateKeywords =
        /\b(date|deadline|snapshot|tge|claim|ends|airdrop\s*ends)\b/i;
      const isoDatePattern = /\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b/;

      let liMatch;
      let rawDate = "";

      while ((liMatch = liPattern.exec(page)) !== null) {
        const liText = cleanText(liMatch[1]);

        if (dateKeywords.test(liText) && isoDatePattern.test(liText)) {
          rawDate = liText;
          break;
        }
      }

      if (rawDate) {
        const parsed = rawDate.match(isoDatePattern);

        if (parsed) {
          const year = Number(parsed[1]);
          const month = Number(parsed[2]);
          const day = Number(parsed[3]);

          if (
            year >= 2024 &&
            year <= 2035 &&
            month >= 1 &&
            month <= 12 &&
            day >= 1 &&
            day <= 31
          ) {
            project.date =
              `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
          }
        }
      }

'@

if ($pattern.IsMatch($content)) {
    $newContent = $pattern.Replace($content, $replacement)
    Set-Content -Path $path -Value $newContent -NoNewline -Encoding utf8
    Write-Host "Блок DATE заменен успешно" -ForegroundColor Green
} else {
    Write-Host "Паттерн не найден - блок DATE не заменен, проверь файл вручную" -ForegroundColor Red
    Write-Host "Выполни: Select-String -Path $path -Pattern '// DATE' -Context 0,60" -ForegroundColor Yellow
    exit 1
}
