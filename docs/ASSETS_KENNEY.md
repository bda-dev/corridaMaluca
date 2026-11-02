# Assets do Kenney — o que baixar e onde colocar

> **O jogo roda 100% sem nenhum asset baixado.** Tudo que falta vira *placeholder procedural*
> (formas coloridas desenhadas por código, sons sintetizados). Cada asset que você adicionar
> substitui o placeholder correspondente automaticamente — não é preciso mexer em código.
>
> Todos os packs abaixo são **CC0 (domínio público)** — kenney.nl.

## Como funciona a troca

O autoload `scripts/autoload/AssetLib.gd` procura cada asset por uma **chave lógica**, nesta ordem:

1. `res://assets/custom/<caminho>` — arte própria do projeto (prioridade)
2. `res://assets/kenney/<caminho>` — packs do Kenney
3. nada encontrado → placeholder procedural

A tabela `TEXTURE_PATHS` no topo do `AssetLib.gd` é o **único lugar** onde os caminhos estão definidos.

## Atalho: importação automática

1. Baixe os packs abaixo e **extraia** todos numa mesma pasta (ex.: `~/Downloads/kenney/`).
2. Na raiz do projeto rode:

```bash
python3 tools/kenney_import.py ~/Downloads/kenney --dry-run   # confere
python3 tools/kenney_import.py ~/Downloads/kenney             # copia
```

3. Abra (ou volte para) o Godot — ele importa os arquivos novos sozinho.

O script tenta vários padrões de nome para cada arquivo (os nomes mudam um pouco entre versões
dos packs). O que ele não achar, continua placeholder. Os nomes listados abaixo são os
**sugeridos** — confira no pack e, se necessário, copie/renomeie à mão.

---

## Lista de packs

| # | Pack | Link | Uso no jogo | Prioridade |
|---|------|------|-------------|-----------|
| 1 | **Racing Pack** | https://kenney.nl/assets/racing-pack | carros vistos de cima, cones, pneus, barris, óleo | alta |
| 2 | **UI Pack** | https://kenney.nl/assets/ui-pack | botões e painéis do menu | alta |
| 3 | **Particle Pack** | https://kenney.nl/assets/particle-pack | fumaça, faíscas, estrelas | alta |
| 4 | **Kenney Fonts** | https://kenney.nl/assets/kenney-fonts | fontes de título e texto | média |
| 5 | **Input Prompts** | https://kenney.nl/assets/input-prompts | ícones de toque nas dicas da largada | média |
| 6 | **Interface Sounds** | https://kenney.nl/assets/interface-sounds | cliques, confirmações, erro | média |
| 7 | **Impact Sounds** | https://kenney.nl/assets/impact-sounds | batidas, pancadas | média |
| 8 | **Digital Audio** | https://kenney.nl/assets/digital-audio | power-ups, choque, teleporte | média |
| 9 | **Sci-fi Sounds** | https://kenney.nl/assets/sci-fi-sounds | motor, foguete, explosões, BOOM | média |
| 10 | **Music Jingles** | https://kenney.nl/assets/music-jingles | vinheta de chegada e de recorde | baixa |
| 11 | **Toon Characters 1** | https://kenney.nl/assets/toon-characters-1 | retratos dos pilotos (recorte manual) | baixa |
| 12 | **Pixel Vehicle Pack** | https://kenney.nl/assets/pixel-vehicle-pack | carros de lado (intro/menu/seleção) | baixa |
| 13 | **Smoke Particles** | https://kenney.nl/assets/smoke-particles | fumaça alternativa (puff branco) | opcional |
| 14 | **Car Kit** | https://kenney.nl/assets/car-kit | **3D** — para renderizar sprites próprios ou uma futura versão 3D | opcional |

---

## Destinos esperados

### `assets/kenney/cars/` — Racing Pack (`PNG/Cars/`)

A arte do carro deve **apontar para CIMA** (padrão do Racing Pack). O jogo gira 90° sozinho.

| Arquivo esperado | Sugestão no pack | Piloto |
|---|---|---|
| `car_comte_eclair.png` | `car_blue_1.png` | Comte Éclair (Jeantaud Duc) |
| `car_lady_nitro.png` | `car_yellow_3.png` | Lady Nitro (Golden Arrow) |
| `car_capitao_foguete.png` | `car_red_5.png` | Capitão Foguete (Spirit of America) |
| `car_doutor_thrust.png` | `car_black_4.png` | Doutor Thrust (ThrustSSC) |
| `car_ze_vapor.png` | `car_green_2.png` | Zé Vapor (La Jamais Contente a vapor) |

> Os carros do Racing Pack são modernos. Para manter o visual "histórico" você pode deixar o
> placeholder procedural (que já desenha cada carro de recorde) ou pintar sprites próprios em
> `assets/custom/cars/` com os mesmos nomes.

**Carros de lado** (intro, menu, seleção) — Pixel Vehicle Pack ou arte própria, apontando para a
**direita**: `side_comte_eclair.png`, `side_lady_nitro.png`, `side_capitao_foguete.png`,
`side_doutor_thrust.png`, `side_ze_vapor.png`.

### `assets/kenney/cars/objects/` — Racing Pack (`PNG/Objects/`)

| Arquivo esperado | Sugestão no pack |
|---|---|
| `tires.png` | `tires_red.png` / `tires_white.png` |
| `cone.png` | `cone_straight.png` |
| `barrel.png` | `barrel_blue.png` |
| `oil.png` | `oil.png` (mancha de óleo) |
| `rock.png` | `rock1.png` |

### `assets/kenney/characters/` — Toon Characters 1

Recorte o **rosto** de um personagem (quadrado, ~256×256, fundo transparente) e salve como:
`comte_eclair.png`, `lady_nitro.png`, `capitao_foguete.png`, `doutor_thrust.png`, `ze_vapor.png`.
O retrato aparece na seleção, na HUD e no pódio. (Sem arquivo = retrato procedural com chapéu e
bigode de cada piloto.)

### `assets/kenney/ui/` — UI Pack + Input Prompts

| Arquivo esperado | Sugestão |
|---|---|
| `button.png` | UI Pack `PNG/Yellow/Default/button_rectangle_depth_gradient.png` |
| `button_pressed.png` | UI Pack `PNG/Yellow/Default/button_rectangle_gradient.png` |
| `panel.png` | UI Pack, qualquer painel 9-slice |
| `touch_hold.png` | Input Prompts, toque/segurar |
| `touch_swipe.png` | Input Prompts, deslizar horizontal |
| `touch_double.png` | Input Prompts, toque duplo |

As bordas 9-slice estão em `UIStyle.button_box()` / `panel_box()` (margem 16–20 px).

### `assets/kenney/effects/` — Particle Pack / Smoke Particles

Texturas **brancas** (o jogo colore): `smoke.png` (ex.: `smoke_04.png` ou `whitePuff00.png`),
`spark.png` (ex.: `spark_05.png`), `star.png` (ex.: `star_06.png`).

### `assets/fonts/` — Kenney Fonts

Copie `Kenney Future.ttf` (títulos) e `Kenney Future Narrow.ttf` (textos) com esses nomes, ou
use `title.ttf` / `body.ttf` para qualquer outra fonte. **Atenção aos acentos**: se alguma letra
(ã, ç, é) não aparecer, o jogo cai automaticamente na fonte padrão do Godot só para ela; para um
visual uniforme prefira uma fonte com suporte completo a português (ex.: *Lilita One*, OFL).

### `assets/kenney/audio/` — sons (`.ogg`, `.wav` ou `.mp3`)

| Nome esperado | Quando toca | Sugestão |
|---|---|---|
| `click` | botões | Interface Sounds `click_001` |
| `type` | máquina de escrever da intro | Interface Sounds `tick_001` |
| `count` / `go` | 3-2-1 / JÁ! | `tick_002` / Digital Audio `powerUp2` |
| `pickup` / `roll` | caixa de item / roleta | Digital Audio `powerUp1` / `tick_004` |
| `boost` | turbo, nitro | Digital Audio `powerUp3` |
| `crash` | carro se desmonta | Impact Sounds `impactMetal_heavy_000` |
| `boing` | trombada, parede | Digital Audio `phaserUp3` |
| `clank` / `land` | peças, cones / pouso | Impact Sounds `impactPlate_light_000` / `impactSoft_heavy_000` |
| `banana` / `splat` / `spin` | banana / óleo / rodopio | `impactSoft_medium_000` / `impactSoft_heavy_001` / `phaserDown1` |
| `rocket` / `explosion` | foguete | Sci-fi Sounds `thrusterFire_000` / `explosionCrunch_000` |
| `boom` | barreira do som, título | Sci-fi Sounds `lowFrequency_explosion_000` |
| `whoosh` | montagem da intro, saltos | Sci-fi Sounds `forceField_000` |
| `zap` / `magnet` / `teleport` / `steam` | especiais e ímã | Digital Audio `zap1` / `zapThreeToneUp` / `phaserUp1` / Sci-fi `forceField_001` |
| `engine` | motor do jogador (loop, pitch varia) | Sci-fi Sounds `engineCircular_000` |
| `lap` / `ops` / `star` | volta / erro / item recebido | Interface Sounds `confirmation_001` / `error_001` / `maximize_001` |
| `finish` / `record` | chegada / novo recorde | Music Jingles `jingles_NES00` / `jingles_NES03` |
| `honk` | buzina da intro e da seleção | (sem equivalente — use um som próprio ou deixe o sintetizado) |
| `music_menu` / `music_race` | músicas em loop | qualquer loop CC0 — sem arquivo toca o chiptune sintetizado |

Sons próprios podem ir em `assets/custom/audio/` com os mesmos nomes (têm prioridade).
