import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

const required = [
  'project.godot',
  'scenes/MainGame.tscn',
  'autoload/EventBus.gd',
  'autoload/SaveManager.gd',
  'autoload/EconomyManager.gd',
  'autoload/GameManager.gd',
  'autoload/DebrisPool.gd',
  'autoload/AudioManager.gd',
  'assets/shaders/block_xray_outline.gdshader',
];

let missing = 0;
for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Missing required Godot file: ${rel}`);
    missing++;
  }
}

if (missing > 0) {
  process.exit(1);
}

console.log('Godot 4 project verification passed.');
