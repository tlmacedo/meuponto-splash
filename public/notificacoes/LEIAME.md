# Mensagens de notificação do Meu Ponto

`mensagens.json` é lido pelo app (URL em `NOTIFICACOES_MANIFEST_URL`). Editar o arquivo e publicar
atualiza as mensagens sem nova build: o app busca o catálogo ao abrir (se o cache tem mais de 6 h) e uma vez por dia em segundo plano com rede; mudanças chegam, em geral, em até ~24 h. **O app nunca executa nada deste arquivo: só exibe texto.**

## Como editar
1. Altere `mensagens.json` (adicione, edite ou desative itens).
2. Rode `./public/scripts/validar_mensagens.zsh` — precisa terminar com `OK`.
   O validador espelha o parser do app (`CatalogoMensagensParser`); em caso de divergência, **o app é a autoridade**.
3. Faça commit e publique como a splash.

## Campos de cada item
| Campo | Obrigatório | Regra |
|---|---|---|
| `id` | sim | único; letras, números, `_ . -`; até 80 caracteres. Repetir um `id` só vale como versionamento (vence a maior `version`); o validador imprime um AVISO |
| `version` | não (1) | inteiro ≥ 1; com `id` repetido, vale a maior |
| `tipo` | sim | um dos 18 tipos (ex.: `ENTRADA_ANTES`, `SAIDA_CASA_DEPOIS`, `SALDO_POSITIVO`) |
| `tom` | sim | `SERIO` ou `ENGRACADO` |
| `severidade` | sim | `INFO`, `LEMBRETE`, `ALERTA`, `CRITICA`. **ALERTA/CRITICA só podem ter tom `SERIO`** |
| `titulo` | sim | até 80 caracteres (unidades UTF-16 após remover espaços das pontas: um emoji conta como 2) |
| `corpo` | sim | até 300 caracteres (mesma contagem do título) |
| `acaoPrincipal` / `acaoSecundaria` | principal sim | `REGISTRAR_ENTRADA`, `REGISTRAR_SAIDA_INTERVALO`, `REGISTRAR_VOLTA_INTERVALO`, `REGISTRAR_SAIDA`, `VER_RESUMO_DIA`, `VER_BANCO_HORAS`, `VER_JORNADA`, `VER_REGRAS`, `JUSTIFICAR`, `ADIAR_LEMBRETE` |
| `active` | não (true) | `false` retira a mensagem na próxima sincronização |
| `peso` | não (1) | 1 a 100: chance relativa no sorteio |
| `minAppVersionCode` / `maxAppVersionCode` | não | faixa de versões do app que exibem a mensagem |
| `startsAt` / `endsAt` | não | ISO-8601 UTC (`2026-12-01T00:00:00Z`); início inclusive, fim exclusivo (campanhas) |

## Variáveis permitidas (as demais descartam a mensagem)
`{nome}` `{horarioEntrada}` `{horarioSaidaIntervalo}` `{horarioVoltaIntervalo}` `{horarioSaida}` `{minutos}`
`{saldoDia}` `{saldoBanco}` `{tempoTrabalhado}` `{tempoRestante}` `{tempoIntervalo}`
`{limiteTurnoSemIntervalo}` `{limiteJornadaDia}` `{tempoDescansoEntreJornadas}`
`{proximaEntradaPermitida}` `{empresaApelido}`

## Como o app escolhe
- Filtra por `active`, janela de datas e versão do app. O usuário escolhe o estilo: **Sérias** (só `SERIO`),
  **Misturar** (todas) ou **Engraçadas** (todas, com as engraçadas valendo 4× no sorteio).
- Sem mensagem disponível para um tipo, o app usa o catálogo embutido dele.
- `schemaVersion` maior que o do app faz o app ignorar o arquivo e manter o último cache.

## Regerar o JSON a partir do app
No repositório do app (a chave de cache do build ignora o ambiente, por isso `--no-build-cache` é obrigatório):
```bash
EXPORTAR_MENSAGENS_PARA=<caminho>/public/notificacoes/mensagens.json \
  ./gradlew :app:cleanTestDebugUnitTest :app:testDebugUnitTest --no-build-cache \
  --tests "br.com.tlmacedo.meuponto.data.notificacao.ExportadorCatalogoEmbutidoTest"
```
**Atenção: isso SOBRESCREVE o `mensagens.json` e apaga edições manuais.**

## Cuidados
- Texto publicado chega a todos os usuários em até ~24 h; revise com atenção e prefira `"active": false` a apagar.
- Mantenha ao menos uma mensagem `SERIO` ativa por tipo.
- O arquivo não pode passar de 512 KB.
