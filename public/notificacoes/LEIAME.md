# Mensagens de notificação do Meu Ponto

`mensagens.json` é lido pelo app (URL em `NOTIFICACOES_MANIFEST_URL`). Editar o arquivo e publicar
atualiza as mensagens em até 24 h, sem nova build. **O app nunca executa nada deste arquivo: só exibe texto.**

## Como editar
1. Altere `mensagens.json` (adicione, edite ou desative itens).
2. Rode `./public/scripts/validar_mensagens.zsh` — precisa terminar com `OK`.
   O validador espelha o parser do app (`CatalogoMensagensParser`); em caso de divergência, **o app é a autoridade**.
3. Faça commit e publique como a splash.

## Campos de cada item
| Campo | Obrigatório | Regra |
|---|---|---|
| `id` | sim | único; letras, números, `_ . -`; até 80 caracteres |
| `version` | não (1) | inteiro ≥ 1; com `id` repetido, vale a maior |
| `tipo` | sim | um dos 18 tipos (ex.: `ENTRADA_ANTES`, `SAIDA_CASA_DEPOIS`, `SALDO_POSITIVO`) |
| `tom` | sim | `SERIO` ou `ENGRACADO` |
| `severidade` | sim | `INFO`, `LEMBRETE`, `ALERTA`, `CRITICA`. **ALERTA/CRITICA só podem ter tom `SERIO`** |
| `titulo` | sim | até 80 caracteres |
| `corpo` | sim | até 300 caracteres |
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

## Cuidados
- Texto publicado chega a todos os usuários em até 24 h; revise com atenção e prefira `"active": false` a apagar.
- Mantenha ao menos uma mensagem `SERIO` ativa por tipo.
- O arquivo não pode passar de 512 KB.
