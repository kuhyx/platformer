# proto-love: tests, lint and the love.js web build (README.md).
# `make web` = .love zip -> love.js compatibility build (no threads, D10)
# -> text-free shell with the __gameReady hook -> size budget.

LOVEJS := node_modules/.bin/love.js
BUDGET := 4000000# bytes gzip, spec/DOCS-tech-reqs.md
TITLE := proto-love
# Only the game's top-level modules ship: spec/, web/, dist/, build/,
# node_modules/ and the docs never enter the .love.
GAME_LUA := $(wildcard *.lua)

.PHONY: test lint web clean

test:
	busted

lint:
	luacheck .

$(LOVEJS): package.json package-lock.json
	npm ci --no-audit --no-fund
	touch $@

web: $(LOVEJS)
	rm -rf dist build
	mkdir -p build
	zip -9 -q -X build/$(TITLE).love $(GAME_LUA)
	$(LOVEJS) -c -t $(TITLE) build/$(TITLE).love dist
	cp web/index.html dist/index.html
	rm -rf dist/theme
	python3 ../tools/size_budget.py dist $(BUDGET)

clean:
	rm -rf dist build
