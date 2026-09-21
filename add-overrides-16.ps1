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
  "yakkamon": {
    "tagline": "A creature-collecting idle farming game on Ronin from the makers of Sunflower Land, with a free Season 0 pre-registration.",
    "summary": "Yakkamon is a creature collector and idle-farming game on Ronin, built by Thought Farm, the studio behind Sunflower Land. You catch monsters and put them to work farming while you are offline, and use your online time for hunting, crafting and arena battles. Season 0 pre-registration is free and needs only an email address. Points from daily activity decide your leaderboard rank, and rank decides which early-access wave you join in Q4 2026 and who receives a Monster NFT. There is no new token: the game uses $FLOWER, the token from the studio's other games.",
    "risks": [
      "This is not a token airdrop. There is no new token, and the rewards are early access, an in-game egg and Monster NFTs for top-ranked trainers.",
      "Early access is limited to the top 100,000 trainers on the Season 0 points leaderboard, so signing up alone does not guarantee a place.",
      "Points from FLOWER deposits require holding real tokens on Ronin or Base. Read the official terms before depositing anything.",
      "Copycat pre-registration pages are common around new game launches. Use only the official site and never enter a seed phrase."
    ],
    "notes": [
      "Sign-up order only decides which Monster Egg tier you get. Early access, your trainer number and the NFT airdrop are all decided by points, so daily activity matters more than registering first.",
      "The Monster Egg is an in-game item and needs no wallet. You do need a wallet for the two on-chain rewards, the Monster NFT airdrop and the Ronin free mint.",
      "The free mint of 10,000 monsters is whitelist-only and scheduled for 1 October. Check the official site for the wallet verification requirement before then."
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