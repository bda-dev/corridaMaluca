#!/usr/bin/env python3
"""Copia arquivos dos packs do Kenney (já baixados e extraídos) para os nomes que o jogo espera.

Uso:
    python3 tools/kenney_import.py ~/Downloads/kenney            # copia
    python3 tools/kenney_import.py ~/Downloads/kenney --dry-run  # só mostra o que faria

<pasta> = qualquer pasta contendo os .zip do Kenney JÁ EXTRAÍDOS (ex.: racing-pack/, ui-pack/...).

Os nomes de arquivo dos packs mudam um pouco entre versões, então cada destino tem uma
lista de padrões (glob no NOME do arquivo, sem diferenciar maiúsculas). O primeiro que casar
é copiado. O que não for encontrado continua usando o placeholder procedural do jogo —
nada quebra. Rode de novo quando quiser; arquivos existentes só são sobrescritos com --force.

Retratos (Toon Characters) e carros de lado (Pixel Vehicle Pack) precisam de recorte/escolha
manual — veja docs/ASSETS_KENNEY.md.
"""
import argparse
import fnmatch
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# destino (relativo à raiz do projeto) -> [(padrão do nome, trecho exigido no caminho ou "")]
MAPPING = {
    # Racing Pack — carros vistos de cima (apontando para cima)
    "assets/kenney/cars/car_comte_eclair.png": [("car_blue_1.png", ""), ("car_blue_*.png", "")],
    "assets/kenney/cars/car_lady_nitro.png": [("car_yellow_3.png", ""), ("car_yellow_*.png", "")],
    "assets/kenney/cars/car_capitao_foguete.png": [("car_red_5.png", ""), ("car_red_*.png", "")],
    "assets/kenney/cars/car_doutor_thrust.png": [("car_black_4.png", ""), ("car_black_*.png", "")],
    "assets/kenney/cars/car_ze_vapor.png": [("car_green_2.png", ""), ("car_green_*.png", "")],
    # Racing Pack — objetos
    "assets/kenney/cars/objects/tires.png": [("tires_red*.png", ""), ("tires_white*.png", ""), ("tire*.png", "racing")],
    "assets/kenney/cars/objects/cone.png": [("cone_straight*.png", ""), ("cone*.png", "racing")],
    "assets/kenney/cars/objects/barrel.png": [("barrel_blue.png", ""), ("barrel*.png", "racing")],
    "assets/kenney/cars/objects/oil.png": [("oil*.png", "")],
    "assets/kenney/cars/objects/rock.png": [("rock*.png", "racing")],
    # Particle Pack / Smoke Particles (texturas brancas)
    "assets/kenney/effects/smoke.png": [("whitepuff0*.png", ""), ("smoke_0*.png", ""), ("smoke*.png", "particle")],
    "assets/kenney/effects/spark.png": [("spark_0*.png", ""), ("spark*.png", "particle")],
    "assets/kenney/effects/star.png": [("star_0*.png", ""), ("star*.png", "particle")],
    # UI Pack — botão amarelo com profundidade, botão "apertado" e painel
    "assets/kenney/ui/button.png": [("button_rectangle_depth_gradient.png", "yellow"), ("button_rectangle_depth_flat.png", "yellow"),
                                    ("buttonlong_yellow.png", ""), ("yellow_button0*.png", "")],
    "assets/kenney/ui/button_pressed.png": [("button_rectangle_gradient.png", "yellow"), ("button_rectangle_flat.png", "yellow"),
                                            ("buttonlong_yellow_pressed.png", ""), ("yellow_button0*.png", "")],
    "assets/kenney/ui/panel.png": [("panel_brown*.png", ""), ("panel*.png", "ui")],
    # Input Prompts — ícones de toque
    "assets/kenney/ui/touch_hold.png": [("touch_hold*.png", ""), ("touch_tap.png", ""), ("touch_tap*.png", "")],
    "assets/kenney/ui/touch_swipe.png": [("touch_swipe_horizontal*.png", ""), ("touch_swipe*.png", ""), ("touch_drag*.png", "")],
    "assets/kenney/ui/touch_double.png": [("touch_double*.png", ""), ("touch_tap_double*.png", "")],
    # Kenney Fonts
    "assets/fonts/Kenney Future.ttf": [("kenney future.ttf", "")],
    "assets/fonts/Kenney Future Narrow.ttf": [("kenney future narrow.ttf", "")],
    # Áudio (Interface Sounds, Impact Sounds, Digital Audio, Sci-fi Sounds, Music Jingles)
    "assets/kenney/audio/click.ogg": [("click_001.ogg", ""), ("click*.ogg", "")],
    "assets/kenney/audio/type.ogg": [("tick_001.ogg", ""), ("tick*.ogg", "")],
    "assets/kenney/audio/count.ogg": [("tick_002.ogg", ""), ("tick*.ogg", "")],
    "assets/kenney/audio/roll.ogg": [("tick_004.ogg", ""), ("tick*.ogg", "")],
    "assets/kenney/audio/go.ogg": [("powerup2.ogg", ""), ("confirmation_002.ogg", "")],
    "assets/kenney/audio/pickup.ogg": [("powerup1.ogg", ""), ("powerup*.ogg", "")],
    "assets/kenney/audio/boost.ogg": [("powerup3.ogg", ""), ("powerup*.ogg", "")],
    "assets/kenney/audio/crash.ogg": [("impactmetal_heavy_000.ogg", ""), ("impactmetal_heavy*.ogg", "")],
    "assets/kenney/audio/clank.ogg": [("impactplate_light_000.ogg", ""), ("impactplate*.ogg", "")],
    "assets/kenney/audio/land.ogg": [("impactsoft_heavy_000.ogg", ""), ("impactsoft*.ogg", "")],
    "assets/kenney/audio/banana.ogg": [("impactsoft_medium_000.ogg", ""), ("impactsoft*.ogg", "")],
    "assets/kenney/audio/splat.ogg": [("impactsoft_heavy_001.ogg", ""), ("impactsoft*.ogg", "")],
    "assets/kenney/audio/zap.ogg": [("zap1.ogg", ""), ("zap*.ogg", "")],
    "assets/kenney/audio/magnet.ogg": [("zapthreetoneup.ogg", ""), ("phaserup2.ogg", "")],
    "assets/kenney/audio/teleport.ogg": [("phaserup1.ogg", ""), ("phaserup*.ogg", "")],
    "assets/kenney/audio/spin.ogg": [("phaserdown1.ogg", ""), ("phaserdown*.ogg", "")],
    "assets/kenney/audio/boing.ogg": [("phaserup3.ogg", ""), ("highup.ogg", "")],
    "assets/kenney/audio/rocket.ogg": [("thrusterfire_000.ogg", ""), ("thruster*.ogg", "")],
    "assets/kenney/audio/explosion.ogg": [("explosioncrunch_000.ogg", ""), ("explosion*.ogg", "")],
    "assets/kenney/audio/boom.ogg": [("lowfrequency_explosion_000.ogg", ""), ("explosioncrunch_004.ogg", ""), ("explosion*.ogg", "")],
    "assets/kenney/audio/whoosh.ogg": [("forcefield_000.ogg", ""), ("thrusterfire_001.ogg", "")],
    "assets/kenney/audio/steam.ogg": [("forcefield_001.ogg", ""), ("forcefield*.ogg", "")],
    "assets/kenney/audio/engine.ogg": [("enginecircular_000.ogg", ""), ("engine*.ogg", "")],
    "assets/kenney/audio/lap.ogg": [("confirmation_001.ogg", ""), ("confirmation*.ogg", "")],
    "assets/kenney/audio/ops.ogg": [("error_001.ogg", ""), ("error*.ogg", "")],
    "assets/kenney/audio/star.ogg": [("maximize_001.ogg", ""), ("select_001.ogg", "")],
    "assets/kenney/audio/finish.ogg": [("jingles_nes00.ogg", ""), ("jingles_*00.ogg", "")],
    "assets/kenney/audio/record.ogg": [("jingles_nes03.ogg", ""), ("jingles_*03.ogg", "")],
}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", type=Path, help="pasta com os packs do Kenney extraídos")
    ap.add_argument("--dry-run", action="store_true", help="não copia, só mostra")
    ap.add_argument("--force", action="store_true", help="sobrescreve arquivos que já existem")
    args = ap.parse_args()
    if not args.source.is_dir():
        print(f"Pasta não encontrada: {args.source}")
        return 1
    files = sorted(p for p in args.source.rglob("*") if p.is_file())
    print(f"{len(files)} arquivos encontrados em {args.source}\n")
    found = missing = 0
    for dest, patterns in MAPPING.items():
        match = None
        for pattern, must_contain in patterns:
            for f in files:
                if fnmatch.fnmatch(f.name.lower(), pattern) and must_contain in str(f).lower():
                    match = f
                    break
            if match:
                break
        target = ROOT / dest
        if match is None:
            missing += 1
            print(f"  --  {dest}  (não encontrado: continua o placeholder)")
            continue
        found += 1
        if target.exists() and not args.force:
            print(f"  ==  {dest}  (já existe; use --force para trocar)")
            continue
        print(f"  OK  {dest}  <-  {match.relative_to(args.source)}")
        if not args.dry_run:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(match, target)
    print(f"\n{found} encontrados, {missing} sem correspondência.")
    print("Abra o projeto no Godot para importar os arquivos novos.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
