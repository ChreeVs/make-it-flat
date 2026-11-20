import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const PORT = Number(process.env.PORT || 3000);

function parseTres(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const resIdx = raw.indexOf('[resource]');
  const body = resIdx >= 0 ? raw.slice(resIdx) : raw;
  const data = {};
  for (const line of body.split('\n')) {
    const m = line.match(/^([a-zA-Z0-9_]+)\s*=\s*(.+)$/);
    if (!m) continue;
    let val = m[2].trim();
    if (val.startsWith('&"') && val.endsWith('"')) val = val.slice(2, -1);
    else if (val.startsWith('"') && val.endsWith('"')) val = val.slice(1, -1);
    data[m[1]] = val;
  }
  const exts = {};
  for (const m of raw.matchAll(/\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"/g)) {
    exts[m[2]] = m[1];
  }
  if (data.albedo_texture) {
    const em = data.albedo_texture.match(/ExtResource\("([^"]+)"\)/);
    if (em && exts[em[1]]) data.albedo_path = exts[em[1]].replace('res://', '/');
  }
  if (data.normal_texture) {
    const em = data.normal_texture.match(/ExtResource\("([^"]+)"\)/);
    if (em && exts[em[1]]) data.normal_path = exts[em[1]].replace('res://', '/');
  }
  return data;
}

function loadCollection(relDir) {
  const dir = path.join(ROOT, relDir);
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .filter((f) => f.endsWith('.tres'))
    .sort()
    .map((f) => ({ file: f, ...parseTres(path.join(dir, f)) }));
}

function parseSkillTree() {
  const ecoPath = path.join(ROOT, 'autoload', 'EconomyManager.gd');
  if (!fs.existsSync(ecoPath)) return { c4Cost: 180, nodes: [] };
  const raw = fs.readFileSync(ecoPath, 'utf8');
  const c4Match = raw.match(/C4_BASE_UNIT_COST:\s*float\s*=\s*([0-9.]+)/);
  const c4Cost = c4Match ? Number(c4Match[1]) : 180;
  const nodes = [];
  const regRe = /_register_upgrade\(\s*&"([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*([0-9.]+),\s*([0-9.]+),\s*(\d+),\s*([0-9.]+),\s*&"([^"]*)",\s*(\d+)/g;
  for (const m of raw.matchAll(regRe)) {
    nodes.push({
      id: m[1],
      title: m[2],
      description: m[3],
      branch: m[4],
      baseCost: Number(m[5]),
      multiplier: Number(m[6]),
      maxLevel: Number(m[7]),
      effectPct: Math.round(Number(m[8]) * 100),
      parentId: m[9] || null,
      minParentLvl: Number(m[10]),
    });
  }
  return { c4Cost, nodes };
}

function loadTextures() {
  const dir = path.join(ROOT, 'assets', 'textures');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .filter((f) => f.endsWith('.png'))
    .sort()
    .map((f) => ({
      name: f,
      url: `/assets/textures/${encodeURIComponent(f)}`,
      kind: f.includes('_n.png')
        ? 'Normal Map'
        : f.startsWith('tex_cracks_')
          ? 'Damage Overlay'
          : f.startsWith('tex_mat_') || f.startsWith('tex_site_') || f.startsWith('tex_roof_') || f.startsWith('tex_asphalt') || f.startsWith('tex_container_')
            ? 'Material / Env'
            : 'Tool Texture',
    }));
}

function esc(s) {
  return String(s ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function renderHtml() {
  const contracts = loadCollection('data/contracts').sort((a, b) => Number(a.tier || 0) - Number(b.tier || 0));
  const materials = loadCollection('data/materials').sort((a, b) => Number(a.hardness_tier || 0) - Number(b.hardness_tier || 0));
  const tools = loadCollection('data/tools').sort((a, b) => Number(a.unlock_cost || 0) - Number(b.unlock_cost || 0));
  const textures = loadTextures();
  const { c4Cost, nodes: skillNodes } = parseSkillTree();

  const tierColors = {
    1: '#73d973',
    2: '#f2c738',
    3: '#ff8c2e',
    4: '#f25952',
    5: '#bf73ff',
  };

  const branchColors = {
    RADICE: '#f5b427',
    POTENZA: '#f97316',
    ECONOMIA: '#4ade80',
    MOBILITA: '#38bdf8',
    AUTOMAZIONE: '#38bdf8',
  };

  const stairsIds = new Set(['tier2_garage', 'tier3_palazzina', 'tier4_warehouse', 'tier5_skyscraper']);

  return `<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Make It Flat — Godot 4.7 Project Inspector</title>
  <style>
    :root {
      --bg: #0b0e14;
      --panel: #131821;
      --border: #273142;
      --amber: #f5b427;
      --cyan: #38bdf8;
      --text: #eef2f7;
      --muted: #93a0b3;
      --green: #4ade80;
      --red: #f87171;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.5;
      padding: 28px 24px 64px;
    }
    .wrap { max-width: 1240px; margin: 0 auto; }
    header {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      padding: 22px 24px;
      background: linear-gradient(135deg, #171d27 0%, #10151e 100%);
      border: 1px solid var(--border);
      border-left: 4px solid var(--amber);
      border-radius: 10px;
      margin-bottom: 22px;
    }
    .brand h1 { font-size: 26px; letter-spacing: 0.04em; font-weight: 800; color: #fff; }
    .brand p { color: var(--muted); font-size: 13px; margin-top: 4px; }
    .run-box {
      background: #0c1017;
      border: 1px solid #2b3545;
      border-radius: 8px;
      padding: 10px 14px;
      font-size: 12px;
      color: var(--muted);
    }
    .run-box code { color: var(--amber); font-family: ui-monospace, monospace; font-size: 12px; }
    .stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(175px, 1fr));
      gap: 12px;
      margin-bottom: 26px;
    }
    .stat {
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 14px 16px;
    }
    .stat .val { font-size: 23px; font-weight: 800; color: var(--amber); }
    .stat .lbl { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }
    section { margin-bottom: 34px; }
    h2 {
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--amber);
      border-bottom: 1px solid var(--border);
      padding-bottom: 8px;
      margin-bottom: 14px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(275px, 1fr));
      gap: 14px;
    }
    .card {
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 14px;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .row { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
    .tier { font-size: 11px; font-weight: 700; letter-spacing: 0.06em; }
    .title { font-size: 15px; font-weight: 700; color: #fff; }
    .desc { font-size: 12px; color: var(--muted); }
    .meta { font-size: 12px; color: #cbd5e1; font-family: ui-monospace, monospace; }
    .money { color: var(--green); font-weight: 700; font-size: 13px; }
    .c4-note { color: var(--red); font-weight: 600; font-size: 12px; }
    .stairs-tag { color: var(--cyan); font-size: 11px; font-weight: 700; letter-spacing: 0.04em; }
    .highlights {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 12px;
      margin-bottom: 28px;
    }
    .hl-card {
      background: #101620;
      border: 1px solid var(--border);
      border-top: 2px solid var(--cyan);
      border-radius: 8px;
      padding: 13px 15px;
    }
    .hl-card strong { display: block; font-size: 13px; color: #fff; margin-bottom: 4px; }
    .hl-card span { font-size: 12px; color: var(--muted); }
    .mat-preview { display: flex; gap: 8px; margin-bottom: 4px; }
    .mat-preview img {
      width: 64px;
      height: 64px;
      border-radius: 6px;
      border: 1px solid var(--border);
      object-fit: cover;
      background: #0a0c10;
    }
    .tex-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
      gap: 12px;
    }
    .tex-card {
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 10px;
      text-align: center;
    }
    .tex-card img {
      width: 100%;
      aspect-ratio: 1;
      object-fit: cover;
      border-radius: 5px;
      border: 1px solid #252e3c;
      background: repeating-conic-gradient(#1b2230 0% 25%, #121721 0% 50%) 50% / 14px 14px;
      margin-bottom: 8px;
    }
    .tex-name { font-size: 11px; color: var(--text); word-break: break-all; font-family: ui-monospace, monospace; }
    .tex-kind { font-size: 10px; color: var(--muted); margin-top: 2px; }
  </style>
</head>
<body>
  <div class="wrap">
    <header>
      <div class="brand">
        <h1>MAKE IT FLAT — GODOT 4.7</h1>
        <p>Simulatore Incrementale di Demolizione 3D in Prima Persona • Ispettore Asset, Skill Tree &amp; Strutture</p>
      </div>
      <div class="run-box">
        <div>Progetto nativo <strong>Godot Engine 4.7 (Jolt Physics)</strong></div>
        <div>Apri <code>project.godot</code> e avvia <code>scenes/MainGame.tscn</code></div>
      </div>
    </header>

    <div class="stats">
      <div class="stat"><div class="val">${contracts.length}</div><div class="lbl">Edifici Architettonici</div></div>
      <div class="stat"><div class="val">${skillNodes.length}</div><div class="lbl">Nodi Skill Tree [K]</div></div>
      <div class="stat"><div class="val">€${c4Cost}</div><div class="lbl">Costo Base per Carica C4</div></div>
      <div class="stat"><div class="val">${tools.length}</div><div class="lbl">Strumenti 3D [1–7]</div></div>
      <div class="stat"><div class="val">${textures.length}</div><div class="lbl">Texture PBR &amp; Env</div></div>
    </div>

    <div class="highlights">
      <div class="hl-card">
        <strong>Architettura Reale &amp; Scale Interne</strong>
        <span>20 forme di blocco (pilastri, pareti sottili, vetrate, solette, tetti a falde e rampe scale percorribili con gradini scolpiti).</span>
      </div>
      <div class="hl-card">
        <strong>Distretto Industriale 3D a 360°</strong>
        <span>Strada asfaltata, gru a torre animata, container ufficio, torri faro, skyline urbano illuminato, colline e viale alberato.</span>
      </div>
      <div class="hl-card">
        <strong>HUD Zero-Lag &amp; Menu Completi</strong>
        <span>Rimossi i popup +€ 3D: contatore denaro animato con accumulatore singolo, Menu Principale orbitale, Intro a 3 step, Pausa e Impostazioni.</span>
      </div>
      <div class="hl-card">
        <strong>Economia Bilanciata &amp; C4 a Pagamento</strong>
        <span>Ogni carica C4 piazzata costa €${c4Cost} (scontabile fino al -50% via Skill Tree) per impedire spam gratuito e premiare la demolizione strategica.</span>
      </div>
    </div>

    <section>
      <h2>Commesse &amp; Strutture Architettoniche (Tier 1–5)</h2>
      <div class="grid">
        ${contracts.map((c) => {
          const tc = tierColors[Number(c.tier)] || '#fff';
          const hasStairs = stairsIds.has(c.contract_id);
          return `<div class="card">
            <div class="row">
              <span class="tier" style="color:${tc}">TIER ${esc(c.tier)}</span>
              <span class="money">+€ ${Math.round(Number(c.completion_bonus || 0))}</span>
            </div>
            <div class="title">${esc(c.title)}</div>
            ${hasStairs ? '<div class="stairs-tag">SCALE INTERNE PERCORRIBILI</div>' : ''}
            <div class="desc">${esc(c.description)}</div>
            <div class="meta">ID: ${esc(c.contract_id)} • Soglia: ${Math.round(Number(c.completion_threshold || 0.88) * 100)}%</div>
          </div>`;
        }).join('')}
      </div>
    </section>

    <section>
      <h2>Albero delle Abilità — Skill Tree [K] (${skillNodes.length} Nodi)</h2>
      <div class="grid">
        ${skillNodes.map((n) => {
          const bc = branchColors[n.branch] || '#f5b427';
          return `<div class="card" style="border-left: 3px solid ${bc}">
            <div class="row">
              <span class="tier" style="color:${bc}">${esc(n.branch)}</span>
              <span class="money">Base € ${Math.round(n.baseCost)}</span>
            </div>
            <div class="title">${esc(n.title)}</div>
            <div class="desc">${esc(n.description)}</div>
            <div class="meta">Max Lv.${n.maxLevel} • +${n.effectPct}%/lv • ${n.parentId ? `Richiede ${esc(n.parentId)} Lv.${n.minParentLvl}` : 'Nodo Radice'}</div>
          </div>`;
        }).join('')}
      </div>
    </section>

    <section>
      <h2>Arsenale Demolizione (Hotbar 1–7)</h2>
      <div class="grid">
        ${tools.map((t) => {
          const isC4 = t.tool_id === 'c4_charge';
          return `<div class="card">
            <div class="row">
              <span class="title">${esc(t.display_name)}</span>
              <span class="money">${Number(t.unlock_cost || 0) === 0 ? 'BASE' : '€ ' + Math.round(Number(t.unlock_cost))}</span>
            </div>
            ${isC4 ? `<div class="c4-note">Costo operativo: € ${c4Cost} per ogni carica piazzata</div>` : ''}
            <div class="meta">DMG: ${esc(t.base_damage)} • Penetrazione: T${esc(t.hardness_penetration)}</div>
            <div class="meta">Cooldown: ${esc(t.attack_cooldown)}s • Portata: ${esc(t.reach_distance)}m • AoE: ${esc(t.aoe_radius || 0)}m</div>
          </div>`;
        }).join('')}
      </div>
    </section>

    <section>
      <h2>Materiali Distruttibili PBR</h2>
      <div class="grid">
        ${materials.map((m) => {
          const tc = tierColors[Number(m.hardness_tier)] || '#fff';
          return `<div class="card">
            <div class="mat-preview">
              ${m.albedo_path ? `<img src="${esc(m.albedo_path)}" alt="${esc(m.display_name)} albedo" />` : ''}
              ${m.normal_path ? `<img src="${esc(m.normal_path)}" alt="${esc(m.display_name)} normal" />` : ''}
            </div>
            <div class="row">
              <span class="title">${esc(m.display_name)}</span>
              <span class="tier" style="color:${tc}">DUREZZA T${esc(m.hardness_tier)}</span>
            </div>
            <div class="meta">HP: ${esc(m.max_hp)} • Massa: ${esc(m.mass_kg)}kg • Valore: €${esc(m.base_money_value)}</div>
            <div class="meta">Roughness: ${esc(m.roughness)} • Metallic: ${esc(m.metallic)}</div>
          </div>`;
        }).join('')}
      </div>
    </section>

    <section>
      <h2>Galleria Texture PBR, Architettura &amp; Crepe (${textures.length} PNG)</h2>
      <div class="tex-grid">
        ${textures.map((tx) => `<div class="tex-card">
          <img src="${tx.url}" alt="${esc(tx.name)}" loading="lazy" />
          <div class="tex-name">${esc(tx.name)}</div>
          <div class="tex-kind">${esc(tx.kind)}</div>
        </div>`).join('')}
      </div>
    </section>
  </div>
</body>
</html>`;
}

const MIME = {
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.jpg': 'image/jpeg',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
};

const server = http.createServer((req, res) => {
  const urlPath = decodeURIComponent((req.url || '/').split('?')[0]);

  if (urlPath === '/' || urlPath === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(renderHtml());
    return;
  }

  if (urlPath.startsWith('/assets/textures/') || urlPath === '/icon.svg') {
    const safePath = path.normalize(path.join(ROOT, urlPath));
    if (safePath.startsWith(ROOT) && fs.existsSync(safePath) && fs.statSync(safePath).isFile()) {
      const ext = path.extname(safePath).toLowerCase();
      res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
      fs.createReadStream(safePath).pipe(res);
      return;
    }
  }

  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('Not found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Make It Flat Godot Project Inspector running at http://0.0.0.0:${PORT}`);
});
