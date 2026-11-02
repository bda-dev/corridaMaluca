#!/usr/bin/env bash
# Build da Vercel: baixa o Godot + modelos web (hashes SHA-512 conferidos), roda o teste de
# fumaça e exporta a versão web para build/web. Se o teste falhar, o deploy NÃO é publicado.
# Também funciona localmente: bash tools/vercel/build.sh
set -euo pipefail

GODOT_VERSION="4.4.1"
GODOT_ZIP="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
GODOT_SHA512="ef4e76880a514257175544952c61191106fdef3095b909bafed9fcbeb230c3e5533920a0f3012882dd4bbde83028a67549825794e2d2c3cf76eba7918b71370e"
TPZ="Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
TPZ_SHA512="8f461c7d6e91a0fbabfc95b1e4ca70ff1732c6f2920956a16b086ec2a85b5f7e238baf4dbce60dcc5630fae3bcb9a1fa2ae2027b92cb495c02d082705715e441"
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${GODOT_WORK_DIR:-${TMPDIR:-/tmp}/godot-build}"
mkdir -p "$WORK"
# diretórios do Godot isolados (modelos de exportação, cache, configurações)
export XDG_DATA_HOME="$WORK/xdg/data" XDG_CONFIG_HOME="$WORK/xdg/config" XDG_CACHE_HOME="$WORK/xdg/cache"
TEMPLATES="$XDG_DATA_HOME/godot/export_templates/${GODOT_VERSION}.stable"
GODOT="$WORK/godot"

log() { echo "==> $*"; }

# extrai arquivos de um zip (unzip, ou python3 se não houver unzip)
extract() { # zip destino arquivo...
	local zip="$1" dest="$2"; shift 2
	if command -v unzip > /dev/null; then
		unzip -q -o -j "$zip" "$@" -d "$dest"
	elif command -v python3 > /dev/null; then
		python3 -I - "$zip" "$dest" "$@" << 'PY'
import os, sys, zipfile
z, dest = zipfile.ZipFile(sys.argv[1]), sys.argv[2]
for name in sys.argv[3:]:
    with open(os.path.join(dest, os.path.basename(name)), "wb") as f:
        f.write(z.read(name))
PY
	else
		echo "ERRO: precisa de unzip ou python3 para extrair $zip" >&2
		exit 1
	fi
}

download() { # arquivo sha512
	log "Baixando $1"
	curl -sSfL --retry 3 -o "$WORK/$1" "$BASE_URL/$1"
	echo "$2  $WORK/$1" | sha512sum -c -
}

if [ ! -x "$GODOT" ]; then
	download "$GODOT_ZIP" "$GODOT_SHA512"
	extract "$WORK/$GODOT_ZIP" "$WORK" "Godot_v${GODOT_VERSION}-stable_linux.x86_64"
	mv "$WORK/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$GODOT"
	chmod +x "$GODOT"
	rm -f "$WORK/$GODOT_ZIP"
fi
"$GODOT" --version

if [ ! -f "$TEMPLATES/web_nothreads_release.zip" ]; then
	download "$TPZ" "$TPZ_SHA512"
	mkdir -p "$TEMPLATES"
	# só os modelos web sem threads (o pacote completo tem 1,2 GB)
	extract "$WORK/$TPZ" "$TEMPLATES" templates/version.txt templates/web_nothreads_release.zip templates/web_nothreads_debug.zip
	rm -f "$WORK/$TPZ"
fi

cd "$ROOT"
log "Importando o projeto"
timeout 300 "$GODOT" --headless --path . --import > "$WORK/import.log" 2>&1 || { cat "$WORK/import.log"; exit 1; }

log "Teste de fumaça (telas, toques simulados e corrida completa)"
set +e
timeout 600 "$GODOT" --headless --path . res://tests/SmokeTest.tscn > "$WORK/smoke.log" 2>&1
status=$?
set -e
grep "\[smoke\]" "$WORK/smoke.log" || true
if grep -E "SCRIPT ERROR|Parse Error|Failed to load script" "$WORK/smoke.log"; then
	echo "ERRO: erros de script no teste de fumaça — deploy cancelado" >&2
	exit 1
fi
if [ "$status" -ne 0 ] || ! grep -q "\[smoke\] CHEGADA" "$WORK/smoke.log"; then
	echo "ERRO: teste de fumaça falhou (código $status) — deploy cancelado" >&2
	tail -40 "$WORK/smoke.log" >&2
	exit 1
fi

log "Exportando versão web"
rm -rf build/web
mkdir -p build/web
timeout 300 "$GODOT" --headless --path . --export-release "Web" build/web/index.html > "$WORK/export.log" 2>&1 || { cat "$WORK/export.log"; exit 1; }
if grep -E "ERROR" "$WORK/export.log"; then
	echo "ERRO: falha na exportação web" >&2
	exit 1
fi
ls -la build/web
log "Pronto: build/web"
