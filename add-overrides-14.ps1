$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$target = Join-Path $root "data\overrides.json"
if (-not (Test-Path -LiteralPath $target)) { Write-Host "NOT FOUND data\overrides.json"; exit 1 }

$bakDir = Join-Path $root "_backups"
if (-not (Test-Path -LiteralPath $bakDir)) { New-Item -ItemType Directory -Path $bakDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $target -Destination (Join-Path $bakDir ("overrides.json." + $stamp + ".bak"))

$newJson = @'
{
  "push-chain": {
    "tagline": "A shared-state Layer 1 that lets apps built once serve users on other chains, from the team behind Push Protocol.",
    "summary": "Push Chain is a Layer 1 network from the team behind Push Protocol (formerly EPNS). The idea is that developers deploy an app once and reach users on other chains through their existing wallets, with fees payable in tokens users already hold. Today you take part on the Donut testnet through the Push Portal, where quests, daily check-ins and referrals earn points. Everything is free to do, so the real cost is your time, not money.",
    "risks": [
      "The PC token is not live and no TGE date had been announced in the sources we checked, so points are not a confirmed allocation.",
      "The published tokenomics proposal reserves 10% of supply for airdrops, but detailed rules for turning testnet points into tokens were not found.",
      "Mainnet had not launched at the time of review, and testnet tokens have no market value.",
      "Fake portals copying the official design are common around campaigns like this. Use only links from Push's official channels and never enter a seed phrase."
    ],
    "notes": [
      "The testnet faucet gives 1 test PC per address every 6 hours, so plan on-chain quests around it instead of expecting to top up on demand.",
      "Individual quests have their own end dates and rotate over time. Check the date shown on each quest in the Portal rather than relying on a guide."
    ],
    "updatedAt": "2026-09-20"
  },
  "amadeus-protocol": {
    "tagline": "A confidential Layer 1 for AI agents, with a free points beta on AMA Hub.",
    "summary": "Amadeus Protocol is a Layer 1 aimed at AI agents that trade and transact onchain while keeping their strategies private. It uses trusted execution environments and a consensus design called useful proof of work, which points mining power at AI computation. You can join the AMA Hub beta, link wallets, check in daily, run simple agents and finish social quests to earn PRIME Points. The points program is live, but as far as we could find the team has not published how, or whether, points convert into the AMA token.",
    "risks": [
      "Sources disagree on whether an airdrop is confirmed. We found no official commitment to convert PRIME Points into AMA.",
      "We found no official TGE date, so any timeline you see elsewhere should be treated as unconfirmed.",
      "Signing in with a Google account creates a real wallet with a recovery phrase. Store it safely and never share it, because losing it means losing access.",
      "This is a young project with a short public track record."
    ],
    "notes": [
      "Quests on AMA Hub reportedly close on a rolling basis through October 2026, so check the date on each quest.",
      "The sample agents in the Hub are described as watch-only and need your wallet signature for each transaction. Still review what an agent is allowed to do before connecting a wallet."
    ],
    "updatedAt": "2026-09-20"
  }
}
'@

$mergeJs = @'
const fs = require("fs");
const target = "data/overrides.json";
const strip = (s) => s.replace(/^\uFEFF/, "");
const data = JSON.parse(strip(fs.readFileSync(target, "utf8")));
const add = JSON.parse(strip(fs.readFileSync("_overrides-new.json", "utf8")));
for (const k of Object.keys(add)) data[k] = add[k];
fs.writeFileSync(target, JSON.stringify(data, null, 2) + "\n", "utf8");
console.log("OK: merged " + Object.keys(add).join(", "));
'@

$newPath = Join-Path $root "_overrides-new.json"
$jsPath = Join-Path $root "_merge-overrides.js"
[System.IO.File]::WriteAllText($newPath, $newJson, $utf8)
[System.IO.File]::WriteAllText($jsPath, $mergeJs, $utf8)

try {
  node $jsPath
} finally {
  Remove-Item -LiteralPath $newPath -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $jsPath -ErrorAction SilentlyContinue
}