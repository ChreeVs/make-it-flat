# Make It Flat - 3D Incremental Demolition Simulator

Un simulatore di demolizione fisica 3D e incrementale in prima persona realizzato in **Godot 4.7** con motore fisico **Godot Jolt**.

Il giocatore veste i panni di un operaio edile specializzato in demolizioni: partendo da attrezzi base e piccoli cantieri rurali, abbatte strutture complesse e megastrutture, ricava capitale dalle macerie e dai crolli per gravità, potenzia la propria attrezzatura e sblocca tecnologie esplosive ed orbitali fino al Prestigio aziendale.

---

## 🎮 Caratteristiche Principali

* **Visuale FPS Libera & Fluida**: Visuale in prima persona senza trascinamento del mouse; reattività immediata, salto, corsa e allungo.
* **Sistema Fisico Static-to-Dynamic (Godot Jolt)**:
  * Ogni struttura è composta da blocchi modulari (`0.5m`) stabili e congelati in `FREEZE_MODE_STATIC` allo spawn (zero oscillazioni e zero cali di frame).
  * Un algoritmo **BFS (Breadth-First Search)** multi-sorgente ricalcola l'integrità strutturale: quando i supporti e i pilastri portanti cedono, tutti i blocchi scollegati vengono istantaneamente scongelati in `RigidBody3D` dinamici, crollando sotto l'effetto della gravità.
* **Modelli 3D e Texture Strumenti**:
  * **Piede di Porco**: Barra esagonale in acciaio verniciato con testa a leva e punta a scalpello.
  * **Martello da Carpentiere**: Manico in legno ergonomico e testa battente in acciaio forgiato con levachiodi.
  * **Mazza da Cantiere (3kg)**: Manico in fibra di vetro con bande di sicurezza e testa ottagonale.
  * **Mazza Pesante Demolitrice (8kg)**: Piastre di rinforzo e raggio d'impatto ad area (AoE).
  * **Demolitore Elettrico**: Utensile industriale a percussione continua con pistone pneumatico e punta a scalpello.
  * **Carica Esplosiva C4**: Panetto C4 con display LED e detonazione ad area.
  * **Detonatore Remoto a Catena**: Innesco a radiofrequenza con sequenza temporizzata a catena.
* **Economia Incrementale & Officina**:
  * Guadagno in denaro proporzionale al materiale demolito, con moltiplicatore speciale **Crollo a Catena**.
  * Shop con upgrade scalari esponenziali: Danno, Velocità d'Attacco, Valore Macerie, Allungo e Droni orbitali.
* **Soglia Anti-Pixel Hunting**:
  * Completamento cantiere all'88% della massa con bonus in denaro.
  * Highlight / outline automatico sui blocchi residui quando resta meno del 15%.
* **Progressione & Prestigio**:
  * Cantieri da Tier 1 a Tier 5 (Staccionate, Baracche, Muri, Garage, Palazzina Multipiano e Grattacielo Skyline).
  * Sistema di Prestigio con moltiplicatore permanente (+50% per ciclo).

---

## 🕹️ Comandi

| Tasto | Azione |
|---|---|
| `W`, `A`, `S`, `D` | Movimento |
| `Shift` | Corsa |
| `Spazio` | Salto |
| `C` / `Ctrl` | Accovacciati |
| `Mouse Sinistro (LMB)` | Colpo / Piazzamento Carica C4 / Innesco Detonatore |
| `Mouse Destro (RMB)` | Colpo Pesante (1.65x) / Detona subito i C4 |
| `1`–`7` / Rotellina | Cambia strumento |
| `Q` | Torna allo strumento precedente |
| `F` | Detona tutte le cariche C4 |
| `K` / `Tab` | Albero delle Abilità |
| `B` | Officina: Arsenale e Prestigio |
| `N` | Menu Commesse (Selezione Cantiere da Tier 1 a Tier 5) |
| `E` | Incassa il premio del cantiere (attivo dall'88% di demolizione; al 100% è automatico) |
| `R` (tieni premuto) | Ricostruzione Cantiere |
| `Esc` | Pausa / chiudi menu |

---

## 📂 Architettura del Progetto

```
res://
├── assets/
│   └── textures/              # Texture PBR (legno, metallo verniciato, acciaio, strisce di pericolo)
├── autoload/
│   ├── EventBus.gd            # Event-driven decoupler
│   ├── EconomyManager.gd      # Bilanciamento economico e upgrade
│   ├── DebrisPool.gd          # Pool FIFO per frammenti e corpi rigidi
│   ├── GameManager.gd         # Gestione cantieri ed esplosivi
│   ├── SaveManager.gd         # Salvataggio atomico JSON su disco
│   └── AudioManager.gd        # Sintetizzatore procedurale di impatto e crolli
├── data/
│   ├── contracts/             # Risorse ContractData (Tier 1 -> Tier 5)
│   ├── materials/             # Risorse MaterialData (legno, mattoni, calcestruzzo armato)
│   └── tools/                 # Risorse ToolData
├── scenes/
│   ├── MainGame.tscn          # Scena di gioco principale
│   ├── player/Player.tscn     # Controller FPS
│   ├── structures/            # DestructibleBlock e cantieri
│   ├── tools/                 # Modelli 3D degli strumenti e C4
│   └── ui/                    # HUD, ShopMenu e ContractMenu
└── scripts/                   # Script di logica e costruttori modulari
```

---

## 🚀 Requisiti

* **Godot Engine 4.7+** (con supporto Godot Jolt Physics abilitato).
* **Renderer Forward+** (Direct3D 12 / Vulkan): SSAO, SSIL, riflessi SSR, nebbia volumetrica, cielo HDR.
  La qualità grafica si regola in *Impostazioni → Qualità Grafica* (Bassa / Media / Alta).

---

## 🎨 Grafica & Asset

* **Shader strutture** (`assets/shaders/structure_pbr.gdshader`): texture PBR proiettate in coordinate mondo,
  così muri e pilastri formati da più blocchi appaiono come superfici continue; crepe procedurali che crescono
  con il danno; sporco e variazione cromatica anti-ripetizione.
* **Asset Poly Haven (CC0)** in `assets/polyhaven/`: texture PBR, cielo HDRI, arredi, attrezzi e oggetti di cantiere.
  Licenza pubblico dominio, vedi `assets/polyhaven/LICENSE.md`.
* Le scene degli attrezzi in prima persona si rigenerano con:
  `Godot --headless --path . --script res://scripts/tools/BuildToolModels.gd`
* Foto e misure di prestazioni del gioco:
  `Godot --path . res://scenes/tools/ScreenshotCapture.tscn -- --test-mode --out=<cartella> [--difficulty=hardcore] [--measure=120]`

## 🧪 Test

Le scene `scenes/TestRunner_Sprint2..8.tscn` usano un salvataggio separato (`user://test_save_v1.json`)
e non toccano mai la carriera del giocatore.
