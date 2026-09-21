#!/usr/bin/env node
// site-check.mjs — аудит проекта droply.digital (Next 15, без зависимостей).
//
// Запуск (из корня проекта, PowerShell):
//   npm run build; npm start -- -p 3100      # в отдельном окне (npm run dev закрыть!)
//   node scripts/site-check.mjs               # статика + живой обход
//   node scripts/site-check.mjs --static      # только файлы, сервер не нужен
//   node scripts/site-check.mjs --base http://localhost:3100 --max 400
//
// Отчёт печатается и пишется в out-site-check.txt (уже в .gitignore).
// Копирование в буфер:  Get-Content out-site-check.txt | Set-Clipboard

import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";

const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const opt = (n, d) => { const i = args.indexOf(n); return i >= 0 && args[i + 1] ? args[i + 1] : d; };

const ROOT = process.cwd();
const BASE = opt("--base", "http://localhost:3100").replace(/\/$/, "");
const MAX_PAGES = Number(opt("--max", "500"));
const STATIC_ONLY = flag("--static");
const SLOW_MS = 1500;

const lines = [];
const counts = { FAIL: 0, WARN: 0, OK: 0, INFO: 0 };
function log(level, msg) {
  counts[level]++;
  if (level === "OK") return; // OK не засоряют отчёт, считаются в итоге
  lines.push(`[${level}] ${msg}`);
  console.log(`[${level}] ${msg}`);
}
function section(t) { const s = `\n=== ${t} ===`; lines.push(s); console.log(s); }

const exists = (p) => fs.existsSync(path.join(ROOT, p));
const read = (p) => fs.readFileSync(path.join(ROOT, p), "utf8");

function walk(dir, exts, skip = ["node_modules", ".next", ".git", "_backups", "data/snapshots"]) {
  const out = [];
  const abs = path.join(ROOT, dir);
  if (!fs.existsSync(abs)) return out;
  for (const e of fs.readdirSync(abs, { withFileTypes: true })) {
    const rel = path.join(dir, e.name);
    if (skip.some((s) => rel.replaceAll("\\", "/").includes(s)) || e.name.startsWith("_backup")) continue;
    if (e.isDirectory()) out.push(...walk(rel, exts, skip));
    else if (exts.some((x) => e.name.endsWith(x))) out.push(rel);
  }
  return out;
}

// ───────────────────────── 1. СТАТИКА ─────────────────────────
function staticChecks() {
  section("1. Секреты и .gitignore");
  const gi = exists(".gitignore") ? read(".gitignore") : "";
  for (const need of [".env.local", "node_modules", ".next"]) {
    if (!gi.split(/\r?\n/).some((l) => l.trim() === need || l.trim() === need + "/"))
      log("FAIL", `.gitignore не содержит ${need}`);
    else log("OK", need);
  }
  try {
    const tracked = execSync("git ls-files", { cwd: ROOT, stdio: ["ignore", "pipe", "ignore"] }).toString();
    if (/(^|\n)\.env(\.local)?(\r?\n|$)/.test(tracked)) log("FAIL", ".env/.env.local отслеживается git — уберите: git rm --cached .env.local");
    else log("OK", "env не в git");
  } catch { log("INFO", "git недоступен или репозиторий не инициализирован — пропущено (сделайте commit/копию папки)"); }

  // значения секретов из .env.local ищем в исходниках
  const secrets = [];
  if (exists(".env.local")) {
    for (const l of read(".env.local").split(/\r?\n/)) {
      const m = l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.+?)\s*$/);
      if (m) { const v = m[2].replace(/^["']|["']$/g, ""); if (v.length >= 8) secrets.push([m[1], v]); }
    }
  }
  const srcFiles = [...walk("app", [".ts", ".tsx", ".js", ".mjs"]), ...walk("components", [".ts", ".tsx"]),
    ...walk("lib", [".ts", ".tsx"]), ...walk("scripts", [".js", ".mjs", ".cjs"]),
    ...walk("data", [".ts", ".json"]), ...walk("public", [".js", ".json", ".txt"])];
  let leaked = false;
  for (const f of srcFiles) {
    let txt; try { txt = read(f); } catch { continue; }
    for (const [k, v] of secrets) if (txt.includes(v)) { leaked = true; log("FAIL", `значение ${k} найдено в ${f}`); }
    if (/(sk|pk)_(live|test)_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----/.test(txt))
      log("FAIL", `похоже на ключ/токен в ${f}`);
  }
  if (!leaked) log("OK", "значения из .env.local в коде не найдены");

  section("2. Жёсткие Windows-пути");
  const winRe = /[A-Za-z]:[\\/]{1,2}(Users|Windows|Program Files)[\\/]/;
  let winFound = false;
  for (const f of srcFiles) {
    if (f.endsWith(".json") && f.includes("cache")) continue;
    let txt; try { txt = read(f); } catch { continue; }
    txt.split(/\r?\n/).forEach((ln, i) => { if (winRe.test(ln)) { winFound = true; log("WARN", `${f}:${i + 1} — ${ln.trim().slice(0, 100)}`); } });
  }
  if (!winFound) log("OK", "жёстких путей нет");

  section("3. Регистр в импортах (упадёт на Linux/Vercel)");
  let alias = "@/";
  let aliasTarget = ".";
  try {
    const ts = JSON.parse(read("tsconfig.json").replace(/\/\*[\s\S]*?\*\/|^\s*\/\/.*$/gm, ""));
    const p = ts.compilerOptions?.paths?.["@/*"]?.[0];
    if (p) aliasTarget = p.replace(/\/?\*$/, "") || ".";
  } catch { /* дефолт */ }
  const codeFiles = [...walk("app", [".ts", ".tsx"]), ...walk("components", [".ts", ".tsx"]), ...walk("lib", [".ts", ".tsx"]), ...walk("data", [".ts"])];
  const EXT = ["", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".json", "/index.ts", "/index.tsx", "/index.js"];
  function resolveExact(abs) {
    // проверяет каждый сегмент пути на точное совпадение регистра
    const parts = path.relative(ROOT, abs).split(path.sep);
    let cur = ROOT;
    for (const seg of parts) {
      let names; try { names = fs.readdirSync(cur); } catch { return "missing"; }
      if (names.includes(seg)) { cur = path.join(cur, seg); continue; }
      if (names.some((n) => n.toLowerCase() === seg.toLowerCase())) return "case";
      return "missing";
    }
    return "ok";
  }
  let caseIssues = 0;
  for (const f of codeFiles) {
    const txt = read(f);
    const re = /(?:from\s+|import\s*\(\s*|require\s*\(\s*|import\s+)["']([^"']+)["']/g;
    let m;
    while ((m = re.exec(txt))) {
      const spec = m[1];
      let base;
      if (spec.startsWith("./") || spec.startsWith("../")) base = path.resolve(ROOT, path.dirname(f), spec);
      else if (spec.startsWith(alias)) base = path.resolve(ROOT, aliasTarget, spec.slice(alias.length));
      else continue;
      let status = "missing";
      for (const e of EXT) {
        const r = resolveExact(base + e);
        if (r === "ok") { status = "ok"; break; }
        if (r === "case") status = "case";
      }
      if (status === "case") { caseIssues++; log("FAIL", `${f}: импорт '${spec}' отличается регистром от файла на диске`); }
      else if (status === "missing" && !/\.(css|svg|png|jpg|json)$/.test(spec)) log("WARN", `${f}: импорт '${spec}' не найден`);
    }
  }
  if (!caseIssues) log("OK", "регистр импортов совпадает");

  section("4. Дубли slug в данных");
  for (const file of ["data/projects.generated.ts", "data/projects.ts"]) {
    if (!exists(file)) continue;
    const txt = read(file);
    const slugs = [...txt.matchAll(/["']?slug["']?\s*:\s*["']([^"']+)["']/g)].map((m) => m[1]);
    if (!slugs.length) { log("INFO", `${file}: slug не найдены (другой формат?)`); continue; }
    const seen = new Map(); slugs.forEach((s) => seen.set(s, (seen.get(s) || 0) + 1));
    const dups = [...seen].filter(([, c]) => c > 1);
    log("INFO", `${file}: ${slugs.length} slug`);
    if (dups.length) dups.forEach(([s, c]) => log("FAIL", `${file}: slug '${s}' встречается ${c} раз`));
    else log("OK", `${file}: дублей нет`);
    const bad = slugs.filter((s) => !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(s));
    bad.slice(0, 10).forEach((s) => log("WARN", `${file}: нестандартный slug '${s}'`));
  }

  section("5. Хвосты уборки");
  const junk = ["_backup_links", "_backup_itemlist", "_backup_nav", "_backup_footer", "_dump.txt", "_stats-dump.txt", "_failed_hubs.ts", "lc-check.cjs"];
  const found = junk.filter((j) => exists(j) || exists("scripts/" + j));
  if (found.length) log("WARN", `остались: ${found.join(", ")}`); else log("OK", "мусорных файлов нет");
  for (const need of ["app/sitemap.ts", "app/robots.ts", "lib/hubs.ts"]) if (!exists(need)) log("FAIL", `нет ${need}`);
}

// ───────────────────────── 2. ЖИВОЙ ОБХОД ─────────────────────────
async function get(url, opts = {}) {
  const t0 = performance.now();
  try {
    const r = await fetch(url, { redirect: "manual", signal: AbortSignal.timeout(20000), ...opts });
    const body = await r.text();
    return { status: r.status, ms: Math.round(performance.now() - t0), body, headers: r.headers };
  } catch (e) { return { status: 0, ms: Math.round(performance.now() - t0), body: "", error: e.cause?.code || e.message, headers: new Headers() }; }
}
async function pool(items, n, fn) {
  const res = new Array(items.length); let i = 0;
  await Promise.all(Array.from({ length: n }, async () => { while (i < items.length) { const k = i++; res[k] = await fn(items[k], k); } }));
  return res;
}
const attrs = (tag) => { const o = {}; for (const m of tag.matchAll(/([a-zA-Z:-]+)\s*=\s*("([^"]*)"|'([^']*)')/g)) o[m[1].toLowerCase()] = m[3] ?? m[4]; return o; };
const decode = (s) => s.replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#x27;|&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">");

function analyze(html) {
  const title = decode((html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] || "").trim());
  const metas = [...html.matchAll(/<meta\s[^>]*>/gi)].map((m) => attrs(m[0]));
  const meta = (k) => metas.find((a) => (a.name || a.property || "").toLowerCase() === k)?.content;
  const links = [...html.matchAll(/<link\s[^>]*>/gi)].map((m) => attrs(m[0]));
  const canonical = links.find((a) => (a.rel || "").toLowerCase() === "canonical")?.href;
  const h1 = (html.match(/<h1[\s>]/gi) || []).length;
  const ld = [];
  const ldErrors = [];
  for (const m of html.matchAll(/<script[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/gi)) {
    try { ld.push(JSON.parse(m[1])); } catch (e) { ldErrors.push(e.message); }
  }
  const hrefs = new Set();
  for (const m of html.matchAll(/<a\s[^>]*href="([^"#]+)[^"]*"/gi)) if (m[1].startsWith("/") && !m[1].startsWith("//")) hrefs.add(m[1].split("?")[0]);
  return { title, description: meta("description"), robots: meta("robots"), canonical,
    og: { title: meta("og:title"), description: meta("og:description"), image: meta("og:image") }, h1, ld, ldErrors, hrefs };
}
const flatLd = (ld) => ld.flatMap((x) => (x["@graph"] ? x["@graph"] : [x]));

async function liveChecks() {
  section(`6. Сервер ${BASE}`);
  const ping = await get(BASE + "/");
  if (!ping.status) { log("FAIL", `сервер недоступен (${ping.error}). Запустите: npm run build; npm start -- -p 3100`); return; }
  if (ping.headers.get("x-powered-by") && ping.body.includes("__next_dev") ) log("WARN", "похоже на dev-режим — для реальных метрик используйте build + start");

  section("7. robots.txt и sitemap.xml");
  const robots = await get(BASE + "/robots.txt");
  if (robots.status !== 200) log("FAIL", `/robots.txt → ${robots.status}`);
  else {
    if (!/sitemap:/i.test(robots.body)) log("FAIL", "в robots.txt нет строки Sitemap:");
    if (/^\s*disallow:\s*\/\s*$/im.test(robots.body)) log("FAIL", "robots.txt закрывает весь сайт (Disallow: /)");
    log("INFO", "robots.txt:\n" + robots.body.trim().split("\n").map((l) => "    " + l).join("\n"));
  }
  const sm = await get(BASE + "/sitemap.xml");
  if (sm.status !== 200) { log("FAIL", `/sitemap.xml → ${sm.status}`); return; }
  const entries = [...sm.body.matchAll(/<url>([\s\S]*?)<\/url>/g)].map((m) => ({
    loc: m[1].match(/<loc>([^<]+)<\/loc>/)?.[1]?.trim(), lastmod: m[1].match(/<lastmod>([^<]+)<\/lastmod>/)?.[1] }));
  log("INFO", `в sitemap ${entries.length} URL`);
  const noLast = entries.filter((e) => !e.lastmod).length;
  if (noLast) log("WARN", `sitemap: у ${noLast} URL нет lastmod: ${entries.filter((e) => !e.lastmod).map((e) => e.loc).join(", ")}`);
  else log("OK", "lastmod есть у всех");
  const sameLast = new Set(entries.map((e) => e.lastmod)).size === 1 && entries.length > 5;
  if (sameLast) log("WARN", "sitemap: у всех URL одинаковый lastmod — Google перестанет ему верить; берите реальные даты");
  const locs = entries.map((e) => e.loc).filter(Boolean);
  const dupLocs = locs.filter((l, i) => locs.indexOf(l) !== i);
  if (dupLocs.length) log("FAIL", `sitemap: дубли URL: ${[...new Set(dupLocs)].slice(0, 5).join(", ")}`);
  const prodOrigin = locs[0] ? new URL(locs[0]).origin : null;
  if (prodOrigin) log("INFO", `боевой origin из sitemap: ${prodOrigin}`);
  if (locs.some((l) => /localhost|127\.0\.0\.1/.test(l))) log("FAIL", "в sitemap попали localhost-URL");
  const inSitemap = new Set(locs.map((l) => new URL(l).pathname.replace(/\/$/, "") || "/"));

  section("8. Обход страниц из sitemap");
  const toLocal = (l) => BASE + new URL(l).pathname;
  const pages = locs.slice(0, MAX_PAGES);
  const results = await pool(pages, 6, async (loc) => {
    const url = toLocal(loc);
    const r = await get(url);
    return { loc, url, r, a: r.status === 200 ? analyze(r.body) : null };
  });

  const titles = new Map(), descs = new Map(); const allLinks = new Set(); let slow = 0, times = [];
  for (const { loc, r, a } of results) {
    const p = new URL(loc).pathname;
    times.push(r.ms);
    if (r.status !== 200) { log("FAIL", `${p} → ${r.status}${r.status >= 300 && r.status < 400 ? " → " + r.headers.get("location") : ""} (URL из sitemap должен отдавать 200)`); continue; }
    if (r.ms > SLOW_MS) { slow++; log("WARN", `${p} — ${r.ms} мс`); }
    if (/noindex/i.test(a.robots || "")) log("FAIL", `${p} — в sitemap, но noindex`);
    if (!a.title) log("FAIL", `${p} — нет <title>`);
    else {
      if (a.title.length < 15 || a.title.length > 70) log("WARN", `${p} — длина title ${a.title.length}: «${a.title.slice(0, 60)}»`);
      titles.set(a.title, [...(titles.get(a.title) || []), p]);
    }
    if (!a.description) log("FAIL", `${p} — нет meta description`);
    else {
      if (a.description.length < 50 || a.description.length > 170) log("WARN", `${p} — длина description ${a.description.length}`);
      descs.set(a.description, [...(descs.get(a.description) || []), p]);
    }
    if (!a.canonical) log("FAIL", `${p} — нет canonical`);
    else {
      let cp; try { cp = new URL(a.canonical, BASE).pathname.replace(/\/$/, "") || "/"; } catch { cp = null; }
      if (cp !== (p.replace(/\/$/, "") || "/")) log("WARN", `${p} — canonical указывает на ${a.canonical}`);
      if (/localhost/.test(a.canonical)) log("FAIL", `${p} — canonical на localhost`);
    }
    if (!a.og.title || !a.og.description) log("WARN", `${p} — неполный Open Graph (title/description)`);
    if (!a.og.image) log("INFO", `${p} — нет og:image`);
    if (a.h1 !== 1) log("WARN", `${p} — h1: ${a.h1} (нужен ровно один)`);
    a.ldErrors.forEach((e) => log("FAIL", `${p} — JSON-LD не парсится: ${e}`));
    const nodes = flatLd(a.ld);
    if (!nodes.length && p !== "/") log("INFO", `${p} — нет JSON-LD`);
    for (const n of nodes) {
      if (!n["@type"]) log("WARN", `${p} — JSON-LD узел без @type`);
      if (n["@type"] === "ItemList") {
        const items = n.itemListElement || [];
        if (!items.length) log("WARN", `${p} — ItemList пустой`);
        if (items.length > 50) log("WARN", `${p} — ItemList ${items.length} элементов (>50)`);
        if (items.some((x, i) => x.position !== i + 1)) log("WARN", `${p} — ItemList: position не последовательные`);
      }
      if (n["@type"] === "BreadcrumbList" && !(n.itemListElement || []).length) log("WARN", `${p} — BreadcrumbList пуст`);
      if (n["@type"] === "Event") log("FAIL", `${p} — Event schema (distributeDate пуст, разметка неправдивая)`);
    }
    const dm = JSON.stringify(a.ld).match(/"dateModified"\s*:\s*"([^"]+)"/);
    if (!dm && /^\/(airdrops|chain|category|project)/.test(p)) log("INFO", `${p} — нет dateModified в JSON-LD`);
    a.hrefs.forEach((h) => allLinks.add(h));
  }
  const dupT = [...titles].filter(([, v]) => v.length > 1);
  dupT.slice(0, 15).forEach(([t, v]) => log("WARN", `одинаковый title у ${v.length} страниц: «${t.slice(0, 50)}» → ${v.slice(0, 3).join(", ")}…`));
  const dupD = [...descs].filter(([, v]) => v.length > 1);
  dupD.slice(0, 15).forEach(([d, v]) => log("WARN", `одинаковый description у ${v.length} страниц: «${d.slice(0, 50)}…» → ${v.slice(0, 3).join(", ")}…`));
  const sorted = [...times].sort((a, b) => a - b);
  if (sorted.length) log("INFO", `время ответа: медиана ${sorted[Math.floor(sorted.length / 2)]} мс, p95 ${sorted[Math.floor(sorted.length * 0.95)]} мс, медленных (> ${SLOW_MS} мс): ${slow}`);

  section("9. Внутренние ссылки и 404");
  const internal = [...allLinks].filter((h) => !/^\/(_next|api)\//.test(h) && !/\.(png|jpg|jpeg|svg|ico|webp|xml|txt|css|js)$/i.test(h));
  const toCheck = internal.filter((h) => !inSitemap.has(h.replace(/\/$/, "") || "/")).slice(0, 300);
  log("INFO", `уникальных внутренних ссылок: ${internal.length}, проверяю вне sitemap: ${toCheck.length}`);
  const linkRes = await pool(toCheck, 6, async (h) => ({ h, r: await get(BASE + h) }));
  for (const { h, r } of linkRes) {
    if (r.status === 404 || r.status >= 500 || r.status === 0) log("FAIL", `битая ссылка ${h} → ${r.status || r.error}`);
    else if (r.status >= 300 && r.status < 400) log("WARN", `редирект ${h} → ${r.headers.get("location")}`);
    else if (r.status === 200) {
      const a = analyze(r.body);
      if (!/noindex/i.test(a.robots || "")) log("INFO", `${h} доступна и индексируема, но нет в sitemap`);
    }
  }
  const nf = await get(BASE + "/project/__no-such-project__");
  if (nf.status !== 404) log("FAIL", `несуществующий проект отдаёт ${nf.status} вместо 404 (soft-404)`);
  else log("OK", "несуществующий проект → 404");
  for (const p of ["/chain/__nope__", "/category/__nope__"]) {
    const r = await get(BASE + p);
    if (r.status !== 404) log("WARN", `${p} → ${r.status}, ожидался 404`);
  }

  section("10. Статические маршруты приложения");
  for (const p of ["/", "/about", "/airdrops", "/airdrops/live", "/airdrops/confirmed", "/airdrops/points", "/airdrops/no-token",
    "/calendar", "/contact", "/disclaimer", "/favorites", "/feed", "/privacy", "/stats"]) {
    const r = await get(BASE + p);
    const a = r.status === 200 ? analyze(r.body) : null;
    if (r.status !== 200) log("FAIL", `${p} → ${r.status}`);
    else {
      const thin = /noindex/i.test(a.robots || "");
      const inS = inSitemap.has(p === "/" ? "/" : p);
      if (thin && inS) log("FAIL", `${p}: noindex, но есть в sitemap`);
      if (!thin && !inS && p.startsWith("/airdrops/")) log("WARN", `${p}: индексируется, но нет в sitemap`);
      if (thin) log("INFO", `${p}: noindex (тонкий хаб < HUB_MIN)`);
    }
  }
  const home = await get(BASE + "/");
  const footers = (home.body.match(/<footer[\s>]/gi) || []).length;
  if (footers !== 1) log("WARN", `главная: <footer> ${footers} шт. (ожидается 1 — пункт 9)`);
  else log("OK", "на главной один footer");

  section("11. API");
  const ap = await get(BASE + "/api/projects");
  if (ap.status !== 200) log("FAIL", `/api/projects → ${ap.status}`);
  else {
    try {
      const j = JSON.parse(ap.body); const arr = Array.isArray(j) ? j : j.projects || j.data || [];
      log("INFO", `/api/projects: ${arr.length} проектов, ${ap.ms} мс`);
      if (arr.length) {
        const lc = arr.filter((x) => x.lifeCycle).length;
        log(lc ? "INFO" : "FAIL", `lifeCycle заполнен у ${lc} из ${arr.length}${lc ? "" : " — sync его не подтянул; нужен сырой JSON CryptoRank по одному проекту"}`);
        const vals = {}; arr.forEach((x) => { if (x.lifeCycle) vals[x.lifeCycle] = (vals[x.lifeCycle] || 0) + 1; });
        if (lc) log("INFO", "значения lifeCycle: " + JSON.stringify(vals));
        const dist = arr.filter((x) => x.distributeDate).length;
        log("INFO", `distributeDate заполнен у ${dist} из ${arr.length}`);
        const keys = arr.filter((x) => JSON.stringify(x).match(/PARSE_API_KEY|SYNC_SECRET/)).length;
        if (keys) log("FAIL", "/api/projects отдаёт поля с именами секретов");
      }
    } catch { log("FAIL", "/api/projects вернул не JSON"); }
  }
  const sy = await get(BASE + "/api/sync");
  if (sy.status === 200) log("FAIL", "/api/sync без секрета отвечает 200 — должен быть 401/403");
  else log("OK", `/api/sync без секрета → ${sy.status}`);
  const sy2 = await get(BASE + "/api/sync?secret=wrong");
  if (sy2.status === 200) log("FAIL", "/api/sync принимает неверный секрет");
  else log("OK", `/api/sync с неверным секретом → ${sy2.status}`);
}

// ───────────────────────── MAIN ─────────────────────────
(async () => {
  console.log(`site-check · ${new Date().toISOString()} · cwd=${ROOT}`);
  lines.push(`site-check · ${new Date().toISOString()}`);
  staticChecks();
  if (flag("--build")) {
    section("Сборка");
    try { execSync("npm run build", { cwd: ROOT, stdio: "inherit" }); log("OK", "build прошёл"); }
    catch { log("FAIL", "npm run build упал (закрыт ли npm run dev?)"); }
  }
  if (!STATIC_ONLY) await liveChecks();
  const sum = `\n=== ИТОГО ===\nFAIL: ${counts.FAIL}  WARN: ${counts.WARN}  INFO: ${counts.INFO}  OK-проверок: ${counts.OK}`;
  console.log(sum); lines.push(sum);
  fs.writeFileSync(path.join(ROOT, "out-site-check.txt"), "\uFEFF" + lines.join("\n"), "utf8");
  console.log("\nОтчёт: out-site-check.txt   (в буфер: Get-Content out-site-check.txt | Set-Clipboard)");
  process.exit(counts.FAIL ? 1 : 0);
})();
