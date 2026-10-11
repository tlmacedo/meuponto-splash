#!/usr/bin/env zsh

# -------------------------------------------------
# validar_mensagens.zsh - Valida public/notificacoes/mensagens.json
# com as MESMAS regras do app (CatalogoMensagensParser). Rode antes do commit.
# Uso: ./public/scripts/validar_mensagens.zsh [caminho/mensagens.json]
# -------------------------------------------------
set -euo pipefail

ARQUIVO="${1:-$(cd "$(dirname "$0")/.." && pwd)/notificacoes/mensagens.json}"

python3 - "$ARQUIVO" <<'PY'
# Regras espelhadas do parser: app/src/main/java/br/com/tlmacedo/meuponto/data/notificacao/CatalogoMensagensParser.kt
# (repositório do app). O app é a autoridade: se este script divergir do parser, o parser vale.
# Diferença intencional: o app apenas descarta item inválido; aqui item inválido é ERRO (trava o commit).
import decimal, json, re, sys
from datetime import datetime

TIPOS = {"ENTRADA_ANTES","ENTRADA_NO_HORARIO","ENTRADA_DEPOIS","SAIDA_INTERVALO_ANTES",
 "SAIDA_INTERVALO_NO_HORARIO","SAIDA_INTERVALO_DEPOIS","VOLTA_INTERVALO_ANTES",
 "VOLTA_INTERVALO_NO_HORARIO","VOLTA_INTERVALO_DEPOIS","SAIDA_CASA_ANTES","SAIDA_CASA_NO_HORARIO",
 "SAIDA_CASA_DEPOIS","JORNADA_COMPLETA","SALDO_POSITIVO","SALDO_NEGATIVO",
 "TURNO_MAXIMO_SEM_INTERVALO_PROXIMO","JORNADA_MAXIMA_PROXIMA","ENTRE_JORNADAS"}
TONS = {"SERIO","ENGRACADO"}
SEVERIDADES = {"INFO","LEMBRETE","ALERTA","CRITICA"}
ACOES = {"REGISTRAR_ENTRADA","REGISTRAR_SAIDA_INTERVALO","REGISTRAR_VOLTA_INTERVALO","REGISTRAR_SAIDA",
 "VER_RESUMO_DIA","VER_BANCO_HORAS","VER_JORNADA","VER_REGRAS","JUSTIFICAR","ADIAR_LEMBRETE"}
VARIAVEIS = {"nome","horarioEntrada","horarioSaidaIntervalo","horarioVoltaIntervalo","horarioSaida",
 "minutos","saldoDia","saldoBanco","tempoTrabalhado","tempoRestante","tempoIntervalo",
 "limiteTurnoSemIntervalo","limiteJornadaDia","tempoDescansoEntreJornadas",
 "proximaEntradaPermitida","empresaApelido"}
TITULO_MAX, CORPO_MAX, PESO_MAX, TAMANHO_MAX = 80, 300, 100, 512 * 1024
SCHEMA_SUPORTADO = 1
INT_MIN, INT_MAX = -2**31, 2**31 - 1   # Int do Kotlin (intValueExact)

RE_ID = re.compile(r"[A-Za-z0-9_.-]{1,80}")
RE_VAR = re.compile(r"\{([^{}]*)\}")
RE_INSTANTE = re.compile(r"([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(\.[0-9]{1,9})?Z")  # só dígitos ASCII

def rejeitar(msg):
    print(f"ERRO: {msg}"); sys.exit(1)

def rejeitar_constante(c):
    raise ValueError(f"constante não permitida: {c}")

def inteiro(v):
    """Como JsonObject.inteiro (intValueExact): int, ou número decimal exatamente integral, dentro do Int; bool/string não contam."""
    if isinstance(v, bool): return None
    if isinstance(v, int): n = v
    elif isinstance(v, decimal.Decimal):
        if not v.is_finite() or abs(v) > INT_MAX + 1 or v != v.to_integral_value(): return None
        n = int(v)
    else: return None
    return n if INT_MIN <= n <= INT_MAX else None

def kt_trim(t):
    """Como String.trim() do Kotlin: remove só Char.isWhitespace() (isspace do Python, exceto U+0085)."""
    ini, fim = 0, len(t)
    while ini < fim and t[ini].isspace() and t[ini] != "\x85": ini += 1
    while fim > ini and t[fim - 1].isspace() and t[fim - 1] != "\x85": fim -= 1
    return t[ini:fim]

def instante_ok(v):
    """Como Instant.parse: ISO-8601 estrito com 'Z' final; segundos obrigatórios."""
    if not isinstance(v, str): return False
    m = RE_INSTANTE.fullmatch(v)
    if not m: return False
    try:
        a, mes, d, h, mi, s = (int(x) for x in m.groups()[:6])
        datetime(a, mes, d, h, mi, s)
        return True  # segundos 0..59 (o 60 só valeria às 23:59:60; rejeitado sempre, por segurança)
    except ValueError:
        return False

def utf16(t): return len(t.encode("utf-16-le", "surrogatepass")) // 2

def texto_ok(t, campo, n):
    t = kt_trim(t) if isinstance(t, str) else ""
    if not t or utf16(t) > n:
        return f"{campo} vazio ou maior que {n}"
    for m in RE_VAR.finditer(t):
        if m.group(1) not in VARIAVEIS: return f"variável desconhecida em {campo}: {{{m.group(1)}}}"
    if re.search(r"[{}]", RE_VAR.sub("", t)): return f"chave solta em {campo}"
    return None

def ausente(o, k): return o.get(k) is None

caminho = sys.argv[1]
try:
    bruto = open(caminho, "rb").read()
except OSError:
    rejeitar(f"arquivo não encontrado: {caminho}")
if len(bruto) > TAMANHO_MAX:
    rejeitar(f"arquivo maior que {TAMANHO_MAX} bytes")
if bruto.startswith(b"\xef\xbb\xbf"):
    rejeitar("arquivo com BOM UTF-8 (salve sem BOM)")
try:
    texto_bruto = bruto.decode("utf-8")
except UnicodeDecodeError:
    rejeitar("arquivo não é UTF-8 válido")
try:
    raiz = json.loads(texto_bruto, parse_float=decimal.Decimal, parse_constant=rejeitar_constante)
except Exception as e:
    rejeitar(f"JSON inválido: {e}")
if not isinstance(raiz, dict):
    rejeitar("a raiz deve ser um objeto JSON")
if ausente(raiz, "schemaVersion"):
    schema = 1
else:
    schema = inteiro(raiz["schemaVersion"])
    if schema is None or schema < 1: rejeitar("schemaVersion inválido (precisa ser inteiro >= 1)")
if schema > SCHEMA_SUPORTADO:
    rejeitar(f"schemaVersion {schema} maior que o suportado ({SCHEMA_SUPORTADO})")
if not isinstance(raiz.get("items"), list):
    rejeitar("esperado objeto com lista 'items'")

erros, avisos = [], []
validos = []  # (indice, item) somente dos itens válidos

for i, it in enumerate(raiz["items"]):
    r = f"item {i} ({it.get('id') if isinstance(it, dict) else '?'})"
    if not isinstance(it, dict): erros.append(f"{r}: não é objeto"); continue
    e0 = len(erros)
    def txt(k): return it[k] if isinstance(it.get(k), str) else None   # só string conta
    id_ = kt_trim(txt("id") or "")
    if not RE_ID.fullmatch(id_): erros.append(f"{r}: id inválido")
    if txt("tipo") not in TIPOS: erros.append(f"{r}: tipo desconhecido")
    tom = kt_trim(txt("tom") or "").upper()
    if tom not in TONS: erros.append(f"{r}: tom desconhecido")
    sev = kt_trim(txt("severidade") or "").upper()
    if sev not in SEVERIDADES: erros.append(f"{r}: severidade desconhecida")
    elif sev in ("ALERTA", "CRITICA") and tom != "SERIO":
        erros.append(f"{r}: aviso (ALERTA/CRITICA) deve ter tom SERIO")
    for campo, n in (("titulo", TITULO_MAX), ("corpo", CORPO_MAX)):
        e = texto_ok(txt(campo), campo, n)
        if e: erros.append(f"{r}: {e}")
    if txt("acaoPrincipal") not in ACOES: erros.append(f"{r}: acaoPrincipal desconhecida")
    if not ausente(it, "acaoSecundaria") and txt("acaoSecundaria") not in ACOES:
        erros.append(f"{r}: acaoSecundaria desconhecida")
    if not ausente(it, "peso"):
        p = inteiro(it["peso"])
        if p is None or not (1 <= p <= PESO_MAX): erros.append(f"{r}: peso inválido ou fora de 1..{PESO_MAX}")
    if not ausente(it, "version"):
        v = inteiro(it["version"])
        if v is None or v < 1: erros.append(f"{r}: version inválida")
    if not ausente(it, "active") and not isinstance(it["active"], bool):
        erros.append(f"{r}: active inválido")
    for campo in ("minAppVersionCode", "maxAppVersionCode"):
        if not ausente(it, campo) and inteiro(it[campo]) is None: erros.append(f"{r}: {campo} inválido")
    for campo in ("startsAt", "endsAt"):
        if not ausente(it, campo) and not instante_ok(it[campo]):
            erros.append(f"{r}: {campo} inválido (use ISO-8601 UTC, ex.: 2026-12-01T00:00:00Z)")
    if len(erros) == e0:
        validos.append((i, id_, it))
        mn, mx = inteiro(it.get("minAppVersionCode")), inteiro(it.get("maxAppVersionCode"))
        if mn is not None and mx is not None and mn > mx:
            avisos.append(f"AVISO: {r}: minAppVersionCode > maxAppVersionCode (nunca será exibido)")
        if instante_ok(it.get("startsAt")) and instante_ok(it.get("endsAt")):
            def ini(s): return datetime.strptime(re.sub(r"(\.\d+)?Z$", "", s).replace("T60", "T59"), "%Y-%m-%dT%H:%M:%S")
            if ini(it["startsAt"]) >= ini(it["endsAt"]):
                avisos.append(f"AVISO: {r}: startsAt não é anterior a endsAt (nunca será exibido)")

# Duplicados: só itens válidos; vence a maior version (empate: o primeiro).
grupos = {}
for i, id_, it in validos: grupos.setdefault(id_, []).append((i, it))
vencedores = []
for id_, g in grupos.items():
    if len(g) > 1:
        print(f"AVISO: id duplicado '{id_}' nos itens {[i for i, _ in g]} (o app mantém a maior version)")
    vencedores.append(max(g, key=lambda x: (inteiro(x[1].get("version")) if not ausente(x[1], "version") else 1))[1])
for a in avisos: print(a)

cobertos = {it["tipo"] for it in vencedores if it.get("active") is not False}
for t in sorted(TIPOS - cobertos):
    print(f"AVISO: nenhum item ativo para {t} (o app usará a reserva embutida)")

if erros:
    print(f"\n{len(erros)} erro(s):")
    for e in erros: print(" -", e)
    sys.exit(1)
print(f"OK: {len(raiz['items'])} mensagens válidas.")
PY
