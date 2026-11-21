#!/usr/bin/env zsh

# -------------------------------------------------
# mesclar_lote_mensagens.zsh - Junta um lote de novas mensagens ao mensagens.json.
# Usado pelo gatilho "novas mensagens de notificação" (.claude/skills/novas-mensagens-notificacao).
#
# Uso: ./public/scripts/mesclar_lote_mensagens.zsh [--minimo N] lote1.txt [lote2.txt ...]
#
# Formato do lote (uma mensagem por linha, campos separados por "|"):
#   TIPO|TOM|titulo|corpo        TOM = S (SERIO), E (ENGRACADO) ou A (SARCASTICO)
# Severidade, ações e variáveis permitidas de cada TIPO vêm das mensagens que já existem no catálogo.
# Regras checadas aqui: no mínimo N (padrão 8) mensagens novas por tipo x tom (todos os 18 tipos), título <= 80 e
# corpo <= 300 (UTF-16), só variáveis que o tipo já usa, sem texto repetido no catálogo, sem emoji sobrando.
# Depois de mesclar, rode o validador: ./public/scripts/validar_mensagens.zsh --cobertura 8
# -------------------------------------------------
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
MINIMO=8
LOTES=()
while (( $# > 0 )); do
  case "$1" in
    --minimo) MINIMO="${2:?informe N}"; shift 2 ;;
    *) LOTES+=("$1"); shift ;;
  esac
done
(( ${#LOTES[@]} > 0 )) || { echo "ERRO: informe ao menos um arquivo de lote"; exit 1; }

python3 - "$RAIZ/notificacoes/mensagens.json" "$MINIMO" "${LOTES[@]}" <<'PY'
import collections, json, re, sys
from datetime import datetime, timezone

caminho, minimo, lotes = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
TOM = {"S": "SERIO", "E": "ENGRACADO", "A": "SARCASTICO"}
RE_VAR = re.compile(r"\{(\w+)\}")

def utf16(t): return len(t.encode("utf-16-le", "surrogatepass")) // 2
def erro(m): print(f"ERRO: {m}"); sys.exit(1)

cat = json.load(open(caminho, encoding="utf-8"))
itens = cat["items"]
meta, variaveis, ids = {}, collections.defaultdict(set), set()
for i in itens:
    ids.add(i["id"])
    meta.setdefault(i["tipo"], i)
    variaveis[i["tipo"]] |= set(RE_VAR.findall(i["titulo"] + i["corpo"]))
textos = {(i["titulo"].strip().lower(), i["corpo"].strip().lower()) for i in itens}
titulos = collections.Counter(i["titulo"].strip().lower() for i in itens)

novas, cont = [], collections.Counter()
visto = set()
for arq in lotes:
    for n, linha in enumerate(open(arq, encoding="utf-8").read().splitlines(), 1):
        if not linha.strip(): continue
        onde = f"{arq}:{n}"
        partes = linha.split("|")
        if len(partes) != 4: erro(f"{onde}: esperado TIPO|TOM|titulo|corpo")
        tipo, tom, titulo, corpo = (p.strip() for p in partes)
        if tipo not in meta: erro(f"{onde}: tipo desconhecido {tipo}")
        if tom not in TOM: erro(f"{onde}: tom {tom} inválido (use S, E ou A)")
        if not titulo or utf16(titulo) > 80: erro(f"{onde}: título vazio ou > 80")
        if not corpo or utf16(corpo) > 300: erro(f"{onde}: corpo vazio ou > 300 ({utf16(corpo)})")
        extras = set(RE_VAR.findall(titulo + corpo)) - variaveis[tipo]
        if extras: erro(f"{onde}: variável não usada por {tipo} hoje: {sorted(extras)}")
        if re.search(r"[{}]", RE_VAR.sub("", titulo + corpo)): erro(f"{onde}: chave solta")
        if re.search("[\U0001F300-\U0001FAFF☀-➿]", titulo + corpo): erro(f"{onde}: emoji não permitido")
        chave = (titulo.lower(), corpo.lower())
        if chave in textos or chave in visto: erro(f"{onde}: texto repetido")
        visto.add(chave)
        novas.append((tipo, TOM[tom], titulo, corpo)); cont[(tipo, TOM[tom])] += 1

for t in sorted(meta):
    for m in TOM.values():
        if cont[(t, m)] < minimo: erro(f"lote incompleto: {t} x {m} tem {cont[(t, m)]} (mínimo {minimo})")

seq = collections.defaultdict(int)
for i in itens:
    m = re.fullmatch(r"(.+)_(\d+)", i["id"])
    if m: seq[m.group(1)] = max(seq[m.group(1)], int(m.group(2)))
for tipo, tom, titulo, corpo in novas:
    base = tipo.lower(); seq[base] += 1
    ref = meta[tipo]
    item = {"id": f"{base}_{seq[base]:03d}", "version": 1, "tipo": tipo, "tom": tom,
            "severidade": ref["severidade"], "titulo": titulo, "corpo": corpo,
            "acaoPrincipal": ref["acaoPrincipal"]}
    if ref.get("acaoSecundaria"): item["acaoSecundaria"] = ref["acaoSecundaria"]
    item["active"] = True; item["peso"] = 1
    if item["id"] in ids: erro(f"id repetido {item['id']}")
    ids.add(item["id"]); itens.append(item)

cat["updatedAt"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
with open(caminho, "w", encoding="utf-8") as f:
    json.dump(cat, f, ensure_ascii=False, indent=2); f.write("\n")
print(f"OK: {len(novas)} mensagens novas mescladas ({len(itens)} no catálogo).")
PY
