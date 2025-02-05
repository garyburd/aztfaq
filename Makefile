.PHONY: build serve
TEMPLATE=template.html
FILTER=filter/filter.lua

build: docs/index.html docs/resupply.html

docs/%.html: src/%.md $(TEMPLATE) filter/*.lua
	pandoc --from commonmark+attributes+yaml_metadata_block+gfm_auto_identifiers \
		--to html5 \
		--template=$(TEMPLATE) \
		--lua-filter=$(FILTER) \
		--variable=path:$(patsubst docs%,%,$(patsubst %index.html,%,$@)) \
		--output=$@ $<

serve: build
	python3 -m http.server --directory docs
