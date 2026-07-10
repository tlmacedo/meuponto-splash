#!/usr/bin/env zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_PRINCIPAL="$PROJECT_DIR/public/scripts/adicionar_video_manifest.zsh"
VIDEOS_DIR="$PROJECT_DIR/public/videos"
MANIFEST_PATH="$PROJECT_DIR/public/manifest.json"
BASE_URL="https://meuponto-splash.tl-macedo.workers.dev/videos"

echo "===== EXECUTAR ADICIONAR VIDEO AO MANIFEST ====="
echo "Projeto:  $PROJECT_DIR"
echo "Vídeos:   $VIDEOS_DIR"
echo "Manifest: $MANIFEST_PATH"
echo ""

if [ ! -f "$SCRIPT_PRINCIPAL" ]; then
  echo "ERRO: script principal não encontrado:"
  echo "$SCRIPT_PRINCIPAL"
  exit 1
fi

if [ ! -d "$VIDEOS_DIR" ]; then
  echo "ERRO: pasta de vídeos não encontrada:"
  echo "$VIDEOS_DIR"
  exit 1
fi

if [ ! -f "$MANIFEST_PATH" ]; then
  echo "ERRO: manifest.json não encontrado:"
  echo "$MANIFEST_PATH"
  exit 1
fi

echo "Digite o nome do vídeo dentro de ./public/videos"
echo "Exemplo: novo_video.mp4"
echo ""
printf "Nome do vídeo: "
read VIDEO_NAME

if [ -z "${VIDEO_NAME}" ]; then
  echo "ERRO: nome do vídeo não informado."
  exit 1
fi

VIDEO_PATH="$VIDEOS_DIR/$VIDEO_NAME"

if [ ! -f "$VIDEO_PATH" ]; then
  echo ""
  echo "ERRO: vídeo não encontrado:"
  echo "$VIDEO_PATH"
  echo ""
  echo "Vídeos disponíveis em ./public/videos:"
  find "$VIDEOS_DIR" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' \) -print | sed "s|$VIDEOS_DIR/|- |" | sort
  exit 1
fi

echo ""
echo "Tipo do vídeo:"
echo "  n = NORMAL"
echo "  m = MANDATORY"
echo ""
printf "Escolha o tipo [n/m]: "
read VIDEO_TYPE_OPTION

VIDEO_TYPE_OPTION="$(echo "$VIDEO_TYPE_OPTION" | tr '[:upper:]' '[:lower:]')"

case "$VIDEO_TYPE_OPTION" in
  n)
    VIDEO_TYPE="NORMAL"
    ;;
  m)
    VIDEO_TYPE="MANDATORY"
    ;;
  *)
    echo "ERRO: opção inválida: $VIDEO_TYPE_OPTION"
    echo "Responda somente com n ou m."
    exit 1
    ;;
esac

echo ""
echo "Vídeo selecionado:"
echo "$VIDEO_PATH"
echo ""
echo "Tipo selecionado:"
echo "$VIDEO_TYPE"
echo ""

"$SCRIPT_PRINCIPAL" \
  "$VIDEO_PATH" \
  "$MANIFEST_PATH" \
  "$BASE_URL" \
  "$VIDEO_TYPE"
