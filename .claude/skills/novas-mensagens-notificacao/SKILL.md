---
name: novas-mensagens-notificacao
description: Gatilho para criar e publicar novas mensagens de notificação do Meu Ponto (mínimo 8 novas por tipo e por tom SERIO, ENGRACADO e SARCASTICO), da geração ao merge no GitHub. Use sempre que o dono pedir novas mensagens de notificação.
---

# Novas mensagens de notificação (gatilho)

Repositório `meuponto-splash` publica `public/notificacoes/mensagens.json` (Cloudflare, branch `main`). O app
(`../MeuPonto`) é a autoridade das regras: o parser é `data/notificacao/CatalogoMensagensParser.kt` e os tipos
estão em `domain/model/notificacao`. Os repositórios são separados no GitHub, mas se ajudam: leia o app antes de gerar.

## Regra do lote
- **No mínimo 8 mensagens novas para cada um dos 18 tipos e para cada um dos 3 tons** (SERIO, ENGRACADO, SARCASTICO),
  ou seja, 432 por lote. Todos os tipos aceitam os 3 tons, inclusive ALERTA e CRITICA.
- `SERIO` e `ENGRACADO`: seguem o estilo atual do catálogo (leia 2 ou 3 exemplos de cada tipo antes).
- `SARCASTICO` usa **somente** este prompt, e só para esse tom:
  > Com base em todas as informações que você tem sobre mim, faça uma crítica direta e sem rodeios. Utilize gírias
  > brasileiras e adote um tom sarcástico que resulte em um texto bem engraçado, explorando nuances de humor e ironia.
  > Certifique-se de que a crítica seja clara, mas também divertida, e que destaque aspectos específicos da minha
  > personalidade ou comportamento de forma leve e cômica.
  Aplicação: o "mim" é a pessoa que recebe a notificação, falando do comportamento dela com o ponto (atraso, enrolação,
  almoço, hora extra, banco de horas), usando `{nome}` e as variáveis do tipo. **Nenhum dado pessoal do dono do projeto
  entra no arquivo público.** Sem ofensa a grupos, política, saúde, aparência ou religião. Nos tipos ALERTA e CRITICA o
  sarcasmo nunca esconde a informação do aviso: o horário, o tempo ou o limite (`{limiteTurnoSemIntervalo}`,
  `{limiteJornadaDia}`, `{proximaEntradaPermitida}`...) aparece no texto.
- Texto sem emoji, título até 80 e corpo até 300 caracteres, só variáveis que o tipo já usa, sem repetir texto existente.

## Fluxo (siga na ordem)
1. `git fetch`; conferir branches e PRs abertos (`gh pr list`). Criar `feat/mensagens-AAAAMMDD` a partir de `main`.
2. Ler `LEIAME.md`, o parser e a lista de variáveis permitidas. Se o parser mudou, ajustar `validar_mensagens.zsh` primeiro.
3. Escrever o lote em arquivos fora do repositório (scratchpad), uma mensagem por linha:
   `TIPO|TOM|titulo|corpo` com TOM = `S`, `E` ou `A`. Pode dividir em vários arquivos por grupo de tipos.
4. `./public/scripts/mesclar_lote_mensagens.zsh lote_a.txt lote_b.txt ...` (confere variáveis por tipo, tamanhos,
   mínimo de 8 por par tipo x tom, repetidos, gera ids, severidade e ações a partir do tipo e atualiza `updatedAt`).
5. `./public/scripts/validar_mensagens.zsh --cobertura 8` precisa terminar com `OK`.
6. **Parar e mostrar ao dono** uma amostra (ao menos 1 mensagem de cada tom por tipo) e o PR aberto. Só seguir com
   aprovação explícita. Se reprovar, corrigir, mesclar de novo e repetir 5 e 6.
7. Commit (Conventional Commits, `feat(notificacoes): ...`), push por HTTPS via `gh` se o SSH falhar, PR contra `main`,
   merge (squash), `git pull`, remover branch local e remota.
8. Conferir a publicação: `curl -s https://meuponto-splash.tl-macedo.workers.dev/notificacoes/mensagens.json` e
   comparar `updatedAt` e o total de itens (o deploy da Cloudflare pode levar alguns minutos).

## Cuidados
- Texto publicado chega a todos os usuários em até ~24 h. Prefira `"active": false` a apagar uma mensagem.
- Apps antigos descartam sozinhos itens que não entendem (tom `SARCASTICO`, avisos não sérios); só o app com o estilo
  "Sarcásticas" exibe esses itens.
- Nunca editar o JSON à mão para o lote; use o script de mesclagem.
