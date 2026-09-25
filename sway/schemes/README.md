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
