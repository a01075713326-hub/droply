cd C:\Users\Sasa\Desktop\zip
"lib\events.ts exists: " + (Test-Path .\lib\events.ts)
$hasKey = (Select-String -Path .\.env.local -Pattern '^\s*PARSE_API_KEY\s*=\s*\S' -Quiet) -or [bool]$env:PARSE_API_KEY
"PARSE_API_KEY found: $hasKey"
if ($hasKey) {
  $log = ".\sync-run-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
  "running sync, log: $log"
  cmd /c "node --env-file=.env.local scripts\sync.js > $log 2>&1"
  "exit code: $LASTEXITCODE"
  Get-Content $log -Tail 14 -Encoding UTF8
  "--- warnings (first 15) ---"
  Select-String -Path $log -Pattern 'HTTP [45]|skipped|error|unexpected' | Select-Object -First 15 | ForEach-Object { $_.Line.Trim() }
} else { "no key, sync not started" }

@'
const fs = require("fs");
const t = fs.readFileSync("data/projects.generated.ts", "utf8");
const arr = JSON.parse(t.slice(t.indexOf("= [") + 2, t.lastIndexOf("];") + 1));
const lc = arr.filter((p) => p.lifeCycle);
const by = {};
for (const p of lc) by[p.lifeCycle] = (by[p.lifeCycle] || 0) + 1;
console.log("projects:", arr.length, "| with lifeCycle:", lc.length, "|", JSON.stringify(by));
console.log("with distributeDate:", arr.filter((p) => p.distributeDate).length);
const pre = lc.filter((p) => p.lifeCycle === "funding" || p.lifeCycle === "scheduled");
console.log("funding/scheduled:", pre.map((p) => p.slug + (p.symbol ? " (" + p.symbol + ")" : "")).join(", "));
const e = arr.find((p) => p.slug === "ecash-drivechains");
console.log("ecash-drivechains:", e ? JSON.stringify({ lifeCycle: e.lifeCycle, symbol: e.symbol }) : "not in data");
'@ | Set-Content .\lc-check.cjs -Encoding ASCII
"--- data after sync ---"
node .\lc-check.cjs
"--- type check ---"
npx tsc --noEmit 2>&1 | Select-Object -First 15
"tsc: done"