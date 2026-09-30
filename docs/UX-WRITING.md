# UX writing — padrão Apple HIG aplicado ao rice

_Todo texto visível ao usuário é em português do Brasil (pt-BR), sem
exceção (`AGENTS.md` §10). Inglês só em código, logs, comandos e nomes
de pacote._

Fontes consultadas (§2 do `AGENTS.md`):

- HIG Writing: https://developer.apple.com/design/human-interface-guidelines/writing
- WWDC24 10140 (escrita para UX): https://developer.apple.com/videos/play/wwdc2024/10140/
- Resumo prático: https://dev.to/arshtechpro/4-ios-ux-writing-secrets-that-will-transform-your-apps-user-experience-apple-insiders-reveal-all-3d0f
- Regra local: `AGENTS.md` §10 (vale sobre divergências; HIG é referência).

## 1. Princípios (HIG → §10)

1. **Título = fato, corpo = próximo passo. Nunca repetem.**
   HIG: título curto e descritivo; corpo opcional e breve.
   `notify-send "Bluetooth indisponível" "Para configurar, instale overskride: …"`.
2. **Sem enchimento.** Sem advérbio/amenidade ("rapidamente",
   "simplesmente", "desculpe", "Sim," em botão). Mantém modificador só se
   diferencia a ação ("apenas desligar a tela" vs "suspender").
3. **Porquê antes da ação: "Para X, faça Y".**
   Erro sempre = o que aconteceu + como corrigir, sem culpa, sem "ops!"/"nós".
4. **Verbos nos botões e itens de ação** ("Sair", "Suspender", "Desligar"),
   nunca "OK"/"Vamos lá!"/"Sim, sair".
5. **Um termo por conceito** (lista abaixo). Ação e estado do mesmo conceito
   compartilham a raiz ("Estender" → "estendidos").
6. **Tom segue o contexto**: confirmação é seca (título só, sem festa);
   erro é direto e reparável.
7. **Uma capitalização por tipo de elemento** (sentence case PT-BR):
   - Título de notificação: primeira palavra maiúscula
     ("Modo jogo ativado").
   - Corpo: frase com ponto final ("Para jogar, use gamemoderun.").
   - Prompt tofi: substantivo + dois-pontos ("Esquema: ").
   - Item de menu: infinitivo ou substantivo, primeira maiúscula
     ("Suspender em 5 min").
   - Botão swaynag: verbo ("Sair").
8. **Item de lista filtrável é ASCII digitável.** O tofi filtra por
   substring sem normalizar acento e com `require-match`, então um
   rótulo com acento nunca casa com o que se digita ("horario" diferente
   de "Horario" acentuado) e o Enter morre em silêncio. Filtro usa
   sinônimo ASCII ("Hora", "Avisos", "Itens copiados", "Apenas HDMI");
   acento vive só em título/corpo de notificação e prompt (exibição,
   sem digitação).

## 2. Mini word list (mesmo termo em todo lugar)

| Conceito | Usar | Não usar |
|---|---|---|
| Toggle geral | ativado / desativado | ON/OFF, ligado, habilitado |
| Avisos (masculino plural) | ativados / silenciados | ON/OFF, habilitados, mutados |
| Sair da sessão | Sair | Sim sair, Yes exit, encerrar (variação) |
| Suspender | Suspender | Sleep, Dormir |
| Tampa fechada | Tampa fechada: … | Tampa: …, Lid |
| Luz noturna | Luz noturna (item), luz noturna (corpo) | Noite (sozinho), Night, wlsunset |
| Esquemas | Esquema (prompt), esquemas (lista) | Themes, nomes com variant no título |
| Layouts tofi | Tema (prompt), Temas do Tofi (erro) | tofi minúsculo, Tema tofi |
| Clipboard | Itens copiados (item do hub), Área de transferência (prompt) | Clipboard |
| Energia | Energia | Power, Powermenu |
| Monitores | Monitores (menu/prompt), Apenas HDMI / Apenas notebook (filtro), Só HDMI / Só notebook (títulos), estendidos / espelhados (estados) | Display, Screen, Monitor (singular no prompt) |
| Bloqueio | Bloqueio indisponível / bloquear a tela | Waylock (no texto visível), lock |
| Papel de parede | Papel de parede indisponível / trocar a imagem / mostrar a imagem | Wallpaper, waypaper/swaybg (no texto) |
| Instalar dep. | Para configurar, instale X: <comando> | X não instalado (…), parêntese solto |
| Mudo | Mudo | Mute, Mutado, Silenciado (só p/ notificações) |

## 3. Padrões por elemento

**Notificação de confirmação** (toggle, monitor, OSD): título = fato.
Corpo só se acrescenta estado útil; nunca repete o título.
`Avisos ativados` (sem corpo),
`Só HDMI` + `Notebook desligado.`

**Notificação de erro**: título = o que aconteceu; corpo = `Para X, <comando>`.
`Esquema inválido` + `Para aplicar, escolha um nome da lista. Recebido: …`

**OSD (volume/brilho)**: exceção visual — sem prosa, só `Volume`/`Mudo`/barra.
Não mexer no layout (tamanhos do mako são afinados); já conforme.

**Prompt tofi**: `Ações: `, `Esquema: `, `Tema: `, `Área de transferência: `,
`Emoji: `, `Energia: `, `Luz noturna: `, `Monitores: `.

**Swaynag**: `-m 'Sair do Sway? A sessão será encerrada.' -B 'Sair'`.
Uma mensagem, um verbo. Fonte: `sway/config` (atalho) e `render.sh`
(template do `swaynag-exit.sh` gerado — nunca editar o gerado à mão).

**PCManFM actions**: `Name[pt_BR]` + `Tooltip[pt_BR]` com verbo
("Abrir a pasta no terminal Foot"). `Name`/`Tooltip` em inglês ficam
como fallback.

## 4. O que mudou (antes → depois)

| Arquivo (fonte, não gerado) | Antes | Depois |
|---|---|---|
| `sway/scripts/tofi-menu.sh` (lista) | Tema claro/escuro; Clipboard; Data atual; Rede (iwgtk) | Claro ou escuro; Área de transferência; Data; Rede |
| `tofi-menu.sh` (prompt) | `Sway: ` | `Ações: ` |
| `tofi-menu.sh` (toggle) | `"Notificações" "Ativadas"` | `"Avisos ativados"` (título-fato, sem corpo) |
| `tofi-menu.sh` (filtro ASCII, princípio 8) | `Área de transferência`; `Notificações`; `Horário` | `Itens copiados`; `Avisos`; `Hora` (tofi não normaliza acento; com `require-match` o Enter morria em silêncio) |
| `tofi-menu.sh` (erros) | `"Bluetooth" "overskride não instalado (…)"` | `"Bluetooth indisponível" "Para configurar, instale overskride: …"` ; idem Rede/iwgtk |
| `tofi-menu.sh` (data) | `"Data atual"` | `"Data"` |
| `sway/scripts/scheme-menu.sh` | `"Esquemas" "Biblioteca…não encontrada."` (repete) | `"Biblioteca de esquemas ausente" "Para listar esquemas, rode scripts/update-schemes.sh."`; idem jq/Nenhum/Inválido (com `Recebido: $choice`) |
| `sway/scripts/outputs.sh` | `"Monitores" "Só HDMI (HDMI-A-1, esquerda)"` | `"Só HDMI" "Notebook desligado."`; `"Só notebook" "Monitor externo desligado."`; `"Monitores estendidos" "HDMI à esquerda, notebook à direita."`; `"Monitores espelhados" "A mesma imagem nos dois."` |
| `sway/scripts/game-mode.sh` | `ON — …`, `já ativo`, `OFF — …` | `Já ativo. Para jogar, use gamemoderun.`; `Ativado: performance, sem suspensão…`; `Desativado: perfil restaurado.` (+ `Para voltar a luz noturna, pressione Super+n.` quando aplicável) |
| `sway/scripts/tofi-themes.sh` | `"Tofi" "Pasta…não encontrada."`, prompt `Tema tofi: ` | `"Temas do Tofi indisponíveis" "Para escolher um layout, restaure ~/.config/tofi/themes."`; prompt `Tema: ` |
| `sway/scripts/wallpaper.sh` | `"Papel de parede" "Instale waypaper (…)"` | `"Papel de parede indisponível" "Para trocar a imagem, instale waypaper: …"`; idem swaybg/mostrar |
| `sway/scripts/waylock.sh` | `"Waylock" "waylock não instalado (…)"` | `"Bloqueio indisponível" "Para bloquear a tela, instale waylock: …"`; `"Tema indisponível" "Para bloquear com as cores do tema, rode theme.sh primeiro."` |
| `sway/scripts/tofi-apply.sh` | `"tofi" "Paleta não encontrada (…). Rode…"` | `"Tofi indisponível" "Para aplicar o layout, rode theme.sh primeiro."` (caminho fica só no stderr) |
| `sway/scripts/powermenu.sh` | `5min`, `Tampa: suspender`, `Tampa: nada` | `5 min`, `Tampa fechada: suspender`, `Tampa fechada: apenas desligar a tela` (filtro ASCII, princípio 8) |
| `sway/scripts/nightmenu.sh` | `1000K Noite`, `Gamma 0.8 (Escurecer)`, prompt `Noite: ` | `1000 K — noite`, `Escurecer (gamma 0.8)`, prompt `Luz noturna: ` |
| `sway/scripts/monitormenu.sh` | prompt `Monitor: ` | prompt `Monitores: `; filtro `Apenas HDMI` / `Apenas notebook` (títulos seguem `Só HDMI` / `Só notebook`, princípio 8) |
| `sway/scripts/clipboard.sh` | prompt `Clipboard: ` | prompt `Área de transferência: ` |
| `sway/config` + `render.sh` (swaynag) | EN `You pressed the exit shortcut…` / `Yes, exit sway`; `Sair do Sway?` / `Sim, sair` | `Sair do Sway? A sessão será encerrada.` / `Sair` nos dois |
| `pcmanfm/actions/*.desktop` | só `Tooltip` em inglês | + `Tooltip[pt_BR]` com verbo |

Não alterados de propósito: `volume.sh`/`brightness.sh` (OSD visual, já
mínimo), `yambar/config.yml` (só relógio), `mako/config` (só cor/layout —
texto mora nos scripts acima), comentários de código.

## 5. Verificação

```sh
./scripts/validate.sh   # dash -n + checkbashisms + sway/foot/schemes
```

`swaynag-exit.sh` regenera no próximo `theme.sh apply`; o snapshot no repo
foi sincronizado só no texto (`-m`/`-B`), cores intactas.
