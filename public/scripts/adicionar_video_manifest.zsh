#!/usr/bin/env zsh

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Uso:"
  echo "  ./public/scripts/adicionar_video_manifest.zsh VIDEO.mp4 manifest.json [BASE_URL] [TIPO]"
  echo ""
  echo "Exemplo:"
  echo "  ./public/scripts/adicionar_video_manifest.zsh ./public/videos/novo_video.mp4 ./public/manifest.json"
  echo ""
  echo "Com URL base e tipo:"
  echo "  ./public/scripts/adicionar_video_manifest.zsh ./public/videos/novo_video.mp4 ./public/manifest.json https://meuponto-splash.tl-macedo.workers.dev/videos NORMAL"
  echo "  ./public/scripts/adicionar_video_manifest.zsh ./public/videos/novo_video.mp4 ./public/manifest.json https://meuponto-splash.tl-macedo.workers.dev/videos MANDATORY"
  exit 1
fi

VIDEO_PATH="$1"
MANIFEST_PATH="$2"
BASE_URL="${3:-https://meuponto-splash.tl-macedo.workers.dev/videos}"
VIDEO_TYPE="${4:-NORMAL}"

VIDEO_TYPE_UPPER="$(echo "$VIDEO_TYPE" | tr '[:lower:]' '[:upper:]')"

if [ "$VIDEO_TYPE_UPPER" != "NORMAL" ] && [ "$VIDEO_TYPE_UPPER" != "MANDATORY" ]; then
  echo "ERRO: tipo inválido: $VIDEO_TYPE"
  echo "Use apenas: NORMAL ou MANDATORY"
  exit 1
fi

if [ ! -f "$VIDEO_PATH" ]; then
  echo "ERRO: vídeo não encontrado: $VIDEO_PATH"
  exit 1
fi

if [ ! -f "$MANIFEST_PATH" ]; then
  echo "ERRO: manifest.json não encontrado: $MANIFEST_PATH"
  exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "ERRO: ffprobe não encontrado."
  echo "Instale no Mac com:"
  echo "  brew install ffmpeg"
  exit 1
fi

VIDEO_DIR="$(cd "$(dirname "$VIDEO_PATH")" && pwd)"
VIDEO_FILE="$(basename "$VIDEO_PATH")"
VIDEO_ABS="$VIDEO_DIR/$VIDEO_FILE"

MANIFEST_DIR="$(cd "$(dirname "$MANIFEST_PATH")" && pwd)"
MANIFEST_FILE="$(basename "$MANIFEST_PATH")"
MANIFEST_ABS="$MANIFEST_DIR/$MANIFEST_FILE"

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RETORNO_DIR="$PROJECT_DIR/public/retornos"
BACKUP_DIR="$PROJECT_DIR/public/backup/backups"

TS="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="$RETORNO_DIR/adicionar_video_manifest_${TS}.log"

mkdir -p "$RETORNO_DIR" "$BACKUP_DIR"

{
  echo "===== ADICIONAR VIDEO AO MANIFEST ====="
  echo "DATA_LOCAL=$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "PROJECT_DIR=$PROJECT_DIR"
  echo "VIDEO=$VIDEO_ABS"
  echo "MANIFEST=$MANIFEST_ABS"
  echo "BASE_URL=$BASE_URL"
  echo "VIDEO_TYPE=$VIDEO_TYPE_UPPER"

  echo ""
  echo "===== BACKUP MANIFEST ====="
  BACKUP_FILE="$BACKUP_DIR/manifest_${TS}.json.bak"
  cp "$MANIFEST_ABS" "$BACKUP_FILE"
  echo "Backup salvo em: $BACKUP_FILE"

  echo ""
  echo "===== COLETANDO INFORMACOES DO VIDEO ====="

  SHA256="$(shasum -a 256 "$VIDEO_ABS" | awk '{print $1}')"
  SIZE_BYTES="$(stat -f "%z" "$VIDEO_ABS")"

  DURATION_SECONDS="$(ffprobe -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$VIDEO_ABS")"

  DURATION_MS="$(python3 - <<PY
duration = float("$DURATION_SECONDS")
print(int(round(duration * 1000)))
PY
)"

  echo "Arquivo: $VIDEO_FILE"
  echo "Tipo: $VIDEO_TYPE_UPPER"
  echo "SHA256: $SHA256"
  echo "Size bytes: $SIZE_BYTES"
  echo "Duration seconds: $DURATION_SECONDS"
  echo "Duration ms: $DURATION_MS"

  echo ""
  echo "===== ATUALIZANDO MANIFEST.JSON ====="

  python3 - "$MANIFEST_ABS" "$VIDEO_FILE" "$BASE_URL" "$SHA256" "$SIZE_BYTES" "$DURATION_MS" "$VIDEO_TYPE_UPPER" <<'PY'
import json
import re
import sys
import unicodedata
from pathlib import Path
from datetime import datetime, timezone
from urllib.parse import quote

manifest_path = Path(sys.argv[1])
video_file = sys.argv[2]
base_url = sys.argv[3].rstrip("/")
sha256 = sys.argv[4]
size_bytes = int(sys.argv[5])
duration_ms = int(sys.argv[6])
video_type = sys.argv[7].upper()

if video_type not in {"NORMAL", "MANDATORY"}:
    raise SystemExit(f"Tipo inválido: {video_type}")

def slugify_filename(filename: str) -> str:
    name = Path(filename).stem
    name = unicodedata.normalize("NFKD", name)
    name = "".join(ch for ch in name if not unicodedata.combining(ch))
    name = name.lower()
    name = re.sub(r"[^a-z0-9]+", "_", name)
    name = re.sub(r"_+", "_", name).strip("_")
    return name[:60] if len(name) > 60 else name

def encoded_video_url(filename: str) -> str:
    return f"{base_url}/{quote(filename)}"

data = json.loads(manifest_path.read_text(encoding="utf-8"))

if "schemaVersion" not in data:
    data["schemaVersion"] = 1

if "items" not in data or not isinstance(data["items"], list):
    data["items"] = []

video_id = slugify_filename(video_file)
video_url = encoded_video_url(video_file)

existing = None
for item in data["items"]:
    if item.get("id") == video_id:
        existing = item
        break

if existing:
    old_version = int(existing.get("version") or 1)

    existing.update({
        "version": old_version + 1,
        "type": video_type,
        "active": existing.get("active", True),
        "priority": existing.get("priority", 50),
        "minAppVersionCode": existing.get("minAppVersionCode", 22),
        "maxAppVersionCode": existing.get("maxAppVersionCode", None),
        "startsAt": existing.get("startsAt", None),
        "endsAt": existing.get("endsAt", None),
        "videoUrl": video_url,
        "sha256": sha256,
        "sizeBytes": size_bytes,
        "durationMs": duration_ms,
        "maxViews": existing.get("maxViews", None),
        "cooldownHours": existing.get("cooldownHours", None),
    })

    action = "ATUALIZADO"
else:
    data["items"].append({
        "id": video_id,
        "version": 1,
        "type": video_type,
        "active": True,
        "priority": 50,
        "minAppVersionCode": 22,
        "maxAppVersionCode": None,
        "startsAt": None,
        "endsAt": None,
        "videoUrl": video_url,
        "sha256": sha256,
        "sizeBytes": size_bytes,
        "durationMs": duration_ms,
        "maxViews": None,
        "cooldownHours": None,
    })

    action = "ADICIONADO"

data["updatedAt"] = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

manifest_path.write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8"
)

print(f"ACTION={action}")
print(f"ID={video_id}")
print(f"TYPE={video_type}")
print(f"VIDEO_URL={video_url}")
print(f"ITEMS_TOTAL={len(data['items'])}")
print(f"UPDATED_AT={data['updatedAt']}")
PY

  echo ""
  echo "===== VALIDANDO JSON ====="
  python3 -m json.tool "$MANIFEST_ABS" >/dev/null
  echo "manifest.json válido."

  echo ""
  echo "===== ITEM ADICIONADO/ATUALIZADO ====="
  python3 - "$MANIFEST_ABS" "$VIDEO_FILE" <<'PY'
import json
import re
import sys
import unicodedata
from pathlib import Path

manifest_path = Path(sys.argv[1])
video_file = sys.argv[2]

def slugify_filename(filename: str) -> str:
    name = Path(filename).stem
    name = unicodedata.normalize("NFKD", name)
    name = "".join(ch for ch in name if not unicodedata.combining(ch))
    name = name.lower()
    name = re.sub(r"[^a-z0-9]+", "_", name)
    name = re.sub(r"_+", "_", name).strip("_")
    return name[:60] if len(name) > 60 else name

video_id = slugify_filename(video_file)
data = json.loads(manifest_path.read_text(encoding="utf-8"))

for item in data.get("items", []):
    if item.get("id") == video_id:
        print(json.dumps(item, ensure_ascii=False, indent=2))
        break
PY

  echo ""
  echo "===== OK ====="
  echo "Manifest atualizado: $MANIFEST_ABS"
  echo "Backup salvo em: $BACKUP_FILE"
  echo "Log salvo em: $LOG_FILE"

} 2>&1 | tee "$LOG_FILE"

echo "LOG_FILE=$LOG_FILE"
