#!/usr/bin/env node
// sitemap-projects.mjs — какие проекты в sitemap и по какому признаку.
// Нужен запущенный сервер:  npm start -- -p 3100
// Запуск:  node scripts/sitemap-projects.mjs [--base http://localhost:3100]
// Отчёт:   out-sitemap-projects.txt   (Get-Content out-sitemap-projects.txt -Encoding UTF8 | Set-Clipboard)

import fs from "node:fs";

const i = process.argv.indexOf("--base");
const BASE = (i >= 0 ? process.argv[i + 1] : "http://localhost:3100").replace(/\/$/, "");
const out = [];
const p = (s = "") => { out.push(s); console.log(s); };

const filled = (v) => v !== undefined && v !== null && v !== "" && !(Array.isArray(v) && !v.length) &&
  !(typeof v === "object" && !Array.isArray(v) && !Object.keys(v).length);

const [api, sm] = await Promise.all([fetch(BASE + "/api/projects"), fetch(BASE + "/sitemap.xml")]).catch((e) => {
  console.error("Сервер недоступен:", e.cause?.code || e.message); process.exit(1);
});
const j = await api.json();
const projects = Array.isArray(j) ? j : j.projects || j.data || [];
const xml = await sm.text();
const inSm = new Set([...xml.matchAll(/<loc>[^<]*\/project\/([^<\/]+)<\/loc>/g)].map((m) => decodeURIComponent(m[1])));

const A = projects.filter((x) => inSm.has(x.slug));
const B = projects.filter((x) => !inSm.has(x.slug));
p(`Всего проектов: ${projects.length} | в sitemap: ${A.length} | не в sitemap: ${B.length}`);
const missing = [...inSm].filter((s) => !projects.some((x) => x.slug === s));
if (missing.length) p(`В sitemap, но нет в /api/projects: ${missing.join(", ")}`);

// 1. Какие поля заполнены чаще у тех, кто в sitemap, чем у остальных → это и есть критерий
const keys = [...new Set(projects.flatMap((x) => Object.keys(x)))];
const rows = keys.map((k) => {
  const a = A.filter((x) => filled(x[k])).length, b = B.filter((x) => filled(x[k])).length;
  return { k, a, b, pa: A.length ? a / A.length : 0, pb: B.length ? b / B.length : 0 };
}).sort((x, y) => (y.pa - y.pb) - (x.pa - x.pb));
p(`\n=== Заполненность полей: в sitemap (${A.length}) vs остальные (${B.length}) ===`);
p("поле".padEnd(28) + "в sitemap".padEnd(12) + "остальные".padEnd(12) + "разница");
for (const r of rows) p(r.k.padEnd(28) + `${r.a}/${A.length}`.padEnd(12) + `${r.b}/${B.length}`.padEnd(12) + `${Math.round((r.pa - r.pb) * 100)}%`);

// 2. Поля, похожие на описание: длина у проектов из sitemap
const descKeys = keys.filter((k) => /desc|about|summary|overview|intro|text|note|body/i.test(k));
p(`\n=== Поля-описания: ${descKeys.join(", ") || "не найдены"} ===`);
for (const k of descKeys) {
  const withK = projects.filter((x) => typeof x[k] === "string" && x[k].trim());
  const lens = withK.map((x) => x[k].length).sort((a, b) => a - b);
  p(`${k}: заполнено у ${withK.length}, длина мин ${lens[0] ?? "-"} / медиана ${lens[Math.floor(lens.length / 2)] ?? "-"} / макс ${lens[lens.length - 1] ?? "-"}`);
  const counts = new Map(); withK.forEach((x) => counts.set(x[k], (counts.get(x[k]) || 0) + 1));
  const dupTexts = [...counts].filter(([, c]) => c > 1).sort((a, b) => b[1] - a[1]);
  if (dupTexts.length) p(`  повторяющиеся тексты (шаблон): ${dupTexts.slice(0, 3).map(([t, c]) => `${c}× «${t.slice(0, 50)}…»`).join(" | ")}`);
  const unique = withK.filter((x) => counts.get(x[k]) === 1);
  p(`  уникальных текстов: ${unique.length}${unique.length <= 15 ? " → " + unique.map((x) => x.slug).join(", ") : ""}`);
}

// 3. Таблица проектов из sitemap
p(`\n=== Проекты в sitemap ===`);
p("slug".padEnd(26) + "lifeCycle".padEnd(12) + "поля-описания (длина)");
for (const x of A.sort((a, b) => a.slug.localeCompare(b.slug)))
  p(x.slug.padEnd(26) + String(x.lifeCycle ?? "-").padEnd(12) + descKeys.map((k) => `${k}:${typeof x[k] === "string" ? x[k].length : 0}`).join(" "));

// 4. Проверка гипотезы «sitemap = есть lifeCycle или своё описание»
const hasLc = (x) => filled(x.lifeCycle);
p(`\n=== Гипотеза: в sitemap попадают проекты с lifeCycle ===`);
p(`с lifeCycle всего: ${projects.filter(hasLc).length}; из них в sitemap: ${projects.filter((x) => hasLc(x) && inSm.has(x.slug)).length}`);
const notLc = A.filter((x) => !hasLc(x));
p(`в sitemap БЕЗ lifeCycle: ${notLc.length}${notLc.length ? " → " + notLc.map((x) => x.slug).join(", ") : ""}`);
const lcOut = B.filter(hasLc);
p(`с lifeCycle, но НЕ в sitemap: ${lcOut.length}${lcOut.length ? " → " + lcOut.map((x) => x.slug).join(", ") : ""}`);

fs.writeFileSync("out-sitemap-projects.txt", "\uFEFF" + out.join("\n"), "utf8");
console.log("\nОтчёт: out-sitemap-projects.txt");
