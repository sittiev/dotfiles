# sway/schemes — biblioteca de esquemas de cores (Gogh)

Fonte única dos esquemas escolhíveis no menu `Mod+Shift+x` → "Esquemas de
cores".

## Arquivos

- `gogh-themes-min.json` — snapshot vendorizado de
  <https://github.com/Gogh-Co/Gogh/blob/master/data/themes-min.json>
  (1247 esquemas únicos: 978 dark / 269 light). Licença dual MIT/Apache-2.0
  do Gogh; os `author` originais são preservados dentro de cada entrada do
  JSON.
- `overrides/<nome>.env` — envelopes HSL curadas à mão para esquemas
  específicos (precedência sobre a derivação automática). `apprentice.env`
  reproduz as constantes históricas do `colorlib.sh` para que "escolher
  Apprentice" seja byte-idêntico ao sistema antigo.

## Atualizar

```sh
./scripts/update-schemes.sh   # baixa, valida (jq: contagem, campos, nomes
                              # únicos) e só então substitui o alvo
```

## Consumo

`sway/scripts/schemelib.sh` lê `~/.cache/theme-scheme` (nome do esquema),
deriva as envelopes HSL (min/max por papel: bg, fg, accent, muted, bright),
espelha o L quando `variant ≠ modo`, e exporta `ENV_*` para o `colorlib.sh`.
Esquema desconhecido/ausente ⇒ fallback nas constantes Apprentice atuais.

## Divisão de trabalho com o wallpaper

O esquema **não** escolhe a cor do tema. A imagem escolhe, e o esquema dá o
contraste. `scheme_init` lê a paleta do pywal (`color1..6`) e exporta:

| var | significado |
| --- | --- |
| `WALL_H` | hue médio circular — a família de cor |
| `WALL_S` | croma médio — o quanto a imagem é saturada |
| `WALL_SPREAD` | maior diferença circular entre matizes — quão variada é a imagem |
| `ENV_<papel>_H` | `= WALL_H` para `BG FG ACC MUT` (o hue é da imagem) |

Consequências no caminho derivado (as envelopes de L do esquema continuam
valendo):

- `_chroma_free` descarta as envelopes de S: o piso de S do esquema parava de
  fazer sentido quando quem manda na cor é a imagem. O fundo do Ascendancy,
  por exemplo, tem S 0-4 e deixava o desktop cinza mesmo com wallpaper azul.
- `_chroma_cap` limita o S em `WALL_S × 1.8`, para o esquema não importar
  mais croma do que a imagem tem.
- `_env_widen` abre a faixa de L até um mínimo (16 para ACC/BRI). Derivada de
  uma cor só, a envelope ficava `L 39-45` e os 8 slots "regular" do terminal
  saíam com o mesmo L — uma parede de azul.
- `ENV_ACC_S_MIN` ganha piso no `WALL_S`: seleção precisa ser visível, e uma
  imagem muito dessaturada sozinha não garante isso.
- `render.sh` (`ansi_blend`) puxa os 16 ANSI para dentro de
  `WALL_H ± (WALL_SPREAD × 2 + 12)`, com croma `× WALL_S / S_scheme`.

Overrides não recebem nenhum desses ajustes: as envelopes são curadas à mão e
`apprentice.env` tem que continuar byte-idêntico no dark.

Os testes em `scripts/test-schemelib.sh` (casos 6 e 7) cobrem `chroma_mean` e
`hue_pull`. O caso 6 existe porque `n` não inicializado como subscript de
array em awk cria `hv[""]` em vez de `hv[0]`: a primeira cor era descartada e
o spread saía 153° para uma paleta de 4°, abrindo a janela e deixando o
terminal roxo.
