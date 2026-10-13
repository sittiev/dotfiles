# menu (Rust/ratatui) — hub de utilidades do rice (Mod+Shift+x).
# Mesmo padrão do Makefile de sway/scripts: all/test/clean; o binário
# vai para ~/.local/bin (como swaytiles e os bins do harness).

CARGO ?= cargo
PREFIX ?= $(HOME)/.local

all: build

build:
	$(CARGO) build --release

test:
	$(CARGO) test
	$(CARGO) clippy --all-targets -- -D warnings

# Verificação E2E sem display (ações reais via hooks TOFI_*):
# MENU_SEQ=... ./menu-e2e.sh roda as sequências em scripts/e2e.sh.
e2e:
	$(CARGO) build --release
	./scripts/e2e.sh

install: build
	install -m 755 target/release/menu $(PREFIX)/bin/menu
	@echo "instalado: $(PREFIX)/bin/menu"

clean:
	$(CARGO) clean

.PHONY: all build test e2e install clean