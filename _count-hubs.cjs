const fs = require("fs");
const text = fs.readFileSync("data/projects.generated.ts", "utf8");
const name = text.indexOf("generatedProjects");
const eq = text.indexOf("=", name);
const start = text.indexOf("[", eq);
console.log("name idx:", name, "eq idx:", eq, "start idx:", start);

let depth = 0, inStr = false, esc = false, end = -1;
for (let i = start; i < text.length; i++) {
  const c = text[i];
  if (inStr) {
    if (esc) esc = false;
    else if (c === "\\") esc = true;
    else if (c === "\"") inStr = false;
    continue;
  }
  if (c === "\"") inStr = true;
  else if (c === "[") depth++;
  else if (c === "]") { depth--; if (depth === 0) { end = i; break; } }
}
console.log("end idx:", end);
const arr = JSON.parse(text.slice(start, end + 1));
console.log("total projects:", arr.length);

const byEvent = {};
const byStatus = {};
const confirmedAirdrops = [];
const points = [];
const noToken = [];
for (const p of arr) {
  byEvent[p.event || "(none)"] = (byEvent[p.event || "(none)"] || 0) + 1;
  byStatus[p.status || "(none)"] = (byStatus[p.status || "(none)"] || 0) + 1;
  if (p.event === "Airdrop" && p.status === "Confirmed") confirmedAirdrops.push(p.slug);
  if (p.event === "Points") points.push(p.slug);
  if (p.lifeCycle === "funding" || p.lifeCycle === "scheduled") noToken.push(p.slug);
}
console.log("by event:", JSON.stringify(byEvent, null, 2));
console.log("by status:", JSON.stringify(byStatus, null, 2));
console.log("Confirmed airdrops count:", confirmedAirdrops.length);
console.log("Points programs count:", points.length);
console.log("No-token (funding/scheduled) count:", noToken.length);
