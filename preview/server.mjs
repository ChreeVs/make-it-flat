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
          : f.startsWith('tex_mat_') || f.startsWith('tex_site_')
            ? 'Material Albedo'
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

  const tierColors = {
    1: '#73d973',
    2: '#f2c738',
    3: '#ff8c2e',
    4: '#f25952',
    5: '#bf73ff',
  };

  return `<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Make It Flat — Godot 4 Project Inspector</title>
  <style>
    :root {
      --bg: #0c0f14;
      --panel: #141922;
      --panel-alt: #1a212d;
      --border: #2a3342;
      --amber: #f5b427;
      --text: #eef2f7;
      --muted: #93a0b3;
      --green: #4ade80;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.5;
      padding: 28px 24px 64px;
    }
    .wrap { max-width: 1200px; margin: 0 auto; }
    header {
      display: flex;
      flex-wrap: wrap;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      padding: 22px 24px;
      background: linear-gradient(135deg, #171d27 0%, #11161f 100%);
      border: 1px solid var(--border);
      border-left: 4px solid var(--amber);
      border-radius: 10px;
      margin-bottom: 24px;
    }
    .brand h1 { font-size: 26px; letter-spacing: 0.04em; font-weight: 800; color: #fff; }
    .brand p { color: var(--muted); font-size: 13px; margin-top: 4px; }
    .run-box {
      background: #0d1118;
      border: 1px solid #2b3545;
      border-radius: 8px;
      padding: 10px 14px;
      font-size: 12px;
      color: var(--muted);
    }
    .run-box code { color: var(--amber); font-family: ui-monospace, monospace; font-size: 12px; }
    .stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 12px;
      margin-bottom: 28px;
    }
    .stat {
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 14px 16px;
    }
    .stat .val { font-size: 24px; font-weight: 800; color: var(--amber); }
    .stat .lbl { font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }
    section { margin-bottom: 34px; }
    h2 {
      font-size: 15px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--amber);
      border-bottom: 1px solid var(--border);
      padding-bottom: 8px;
      margin-bottom: 14px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
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
    .mat-preview {
      display: flex;
      gap: 8px;
      margin-bottom: 4px;
    }
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
        <p>Simulatore Incrementale di Demolizione 3D in Prima Persona • Ispettore Asset &amp; Dati di Gioco</p>
      </div>
      <div class="run-box">
        <div>Progetto nativo <strong>Godot Engine 4.7 (Jolt Physics)</strong></div>
        <div>Apri <code>project.godot</code> e avvia <code>scenes/MainGame.tscn</code></div>
      </div>
    </header>

    <div class="stats">
      <div class="stat"><div class="val">${contracts.length}</div><div class="lbl">Commesse Tier 1–5</div></div>
      <div class="stat"><div class="val">${tools.length}</div><div class="lbl">Strumenti 3D</div></div>
      <div class="stat"><div class="val">${materials.length}</div><div class="lbl">Materiali PBR</div></div>
      <div class="stat"><div class="val">${textures.length}</div><div class="lbl">Texture Procedurali</div></div>
    </div>

    <section>
      <h2>Commesse &amp; Strutture (Tier 1–5)</h2>
      <div class="grid">
        ${contracts.map((c) => {
          const tc = tierColors[Number(c.tier)] || '#fff';
          return `<div class="card">
            <div class="row">
              <span class="tier" style="color:${tc}">TIER ${esc(c.tier)}</span>
              <span class="money">+€ ${Math.round(Number(c.completion_bonus || 0))}</span>
            </div>
            <div class="title">${esc(c.title)}</div>
            <div class="desc">${esc(c.description)}</div>
            <div class="meta">ID: ${esc(c.contract_id)} • Soglia: ${Math.round(Number(c.completion_threshold || 0.88) * 100)}%</div>
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
      <h2>Arsenale Demolizione (Hotbar 1–7)</h2>
      <div class="grid">
        ${tools.map((t) => `<div class="card">
          <div class="row">
            <span class="title">${esc(t.display_name)}</span>
            <span class="money">${Number(t.unlock_cost || 0) === 0 ? 'BASE' : '€ ' + Math.round(Number(t.unlock_cost))}</span>
          </div>
          <div class="meta">DMG: ${esc(t.base_damage)} • Penetrazione: T${esc(t.hardness_penetration)}</div>
          <div class="meta">Cooldown: ${esc(t.attack_cooldown)}s • Portata: ${esc(t.reach_distance)}m • AoE: ${esc(t.aoe_radius || 0)}m</div>
        </div>`).join('')}
      </div>
    </section>

    <section>
      <h2>Galleria Texture PBR &amp; Crepe (${textures.length} PNG)</h2>
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
