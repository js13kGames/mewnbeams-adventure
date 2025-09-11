JS_FILES := \
	src/constants.js \
	src/utils.js \
	src/enemyActions.js \
	src/sprite.js \
	src/bodyBg.js \
	src/minimap.js \
	src/character.js \
	src/card.js \
	src/player.js \
	src/enemyLibrary.js \
	src/cardLibrary.js \
	build/cardConstants.js \
	src/cardManager.js \
	src/enemyManager.js \
	src/eventUi.js \
	src/eventLibrary.js \
	src/fightGenerator.js \
	src/gameFlow.js \
	src/main.js

IMAGES := $(wildcard src/*.png)
IMAGES_DIST := $(IMAGES:src/%.png=dist/%.webp)
IMAGES_DEV := $(IMAGES:src/%.png=dev/%.webp)

JS_DEV := $(JS_FILES:src/%=dev/%)


.PHONY: all report clean

all: $(IMAGES_DEV) dev/index.html mewnbeams-adventure.zip report

clean:
	rm -rf dev/*
	rm -rf dev/.[!.]*
	rm -rf dist/*
	rm -rf dist/.[!.]*
	rm -rf build/*
	rm -rf build/.[!.]*

dev/%.webp: dist/%.webp
	cp $^ $@

dev/%.js: src/%.js
	cp $^ $@

dev/build/cardConstants.js: build/cardConstants.js
	@mkdir -p dev/build
	@cp $^ $@

dev/styles.css: build/styles-min.css
	cp $^ $@

dev/index.html: build/index.html $(IMAGES_DEV) $(JS_DEV) dev/build/cardConstants.js combine-dev.py dev/styles.css
	python3 combine-dev.py $(JS_DEV) > $@


# we save 20 bytes replacing forEach with map
build/cardConstants.js: src/cardLibrary.js generateCardConstants.js
	@cat $< | node generateCardConstants.js > $@
build/main-max.js: $(JS_FILES)
	@echo $@ "<-" $^
	@cat $^ | sed 's/[.]forEach[(]/.map(/g' > build/main-max.js

build/main-min.js: build/main-max.js
	@echo $@ "<-" $^
	@npx google-closure-compiler --js=build/main-max.js --js_output_file=build/main-min-1.js --compilation_level=ADVANCED_OPTIMIZATIONS
	@npx uglifyjs build/main-min-1.js -c -m --mangle-props --toplevel > build/main-min-2.js
	@cat build/main-min-2.js | sed 's/window[.]//g' > $@
# 	npx uglifyjs build/main-min-1.js \
# 	    --compress \
# 	        arrows=true,booleans=true,collapse_vars=true,comparisons=true,dead_code=true,drop_console=true,drop_debugger=true,hoist_funs=true,hoist_props=true,hoist_vars=true,if_return=true,inline=3,join_vars=true,keep_fargs=false,keep_infinity=false,loops=true,module=true,negate_iife=true,properties=true,pure_getters=true,reduce_funcs=true,reduce_vars=true,sequences=true,side_effects=true,strings=true,switches=true,templates=true,top_retain=false,toplevel=true,typeofs=true,unsafe=true,unsafe_comps=true,unsafe_Function=true,unsafe_math=true,unsafe_proto=true,unsafe_regexp=true,unsafe_undefined=true,unused=true \
# 	    --mangle \
# 	    --toplevel \
# 	    --output $@

build/styles-min.css: src/styles.scss optimize-css.js
	@echo $@ "<-" $<
	@npx sass $< $@-1 --style=compressed --no-source-map
	@cat $@-1 | node optimize-css.js > $@

build/index.html: src/index.html
	@echo $@ "<-" $^
	@ npx html-minifier \
		--collapse-whitespace \
		--remove-comments \
		--remove-optional-tags \
		--remove-redundant-attributes \
		--remove-script-type-attributes \
		--remove-tag-whitespace \
		-o $@ \
		$^


# There re two compression methods here, I'm getting basically the same
# results for each atm, but might be worth trying later too.
dist/%.webp: src/%.png
	@echo $@ "<-" $^
	@cwebp -lossless -q 100 -m 6 -z 9 -metadata none $^ -o $@
# 	@magick $^ -define webp:lossless=true -quality 100 -define webp:method=6 -strip $@

dist/styles-min.css: build/styles-min.css
	cp $^ $@

dist/index.html: build/index.html build/main-min.js build/styles-min.css combine.py
	@echo $@ "<-" $^
	@python3 combine.py > $@

mewnbeams-adventure.zip: dist/index.html $(IMAGES_DIST)
	@echo $@ "<-" $^
	@rm -f $@ dist/@
	@cd dist && 7z a -tzip -bd -bso0 -bsp0 -mx9 $@ $($^:dist/%=%)
	@mv dist/$@ $@
	@npx advzip --recompress --shrink-insane -q -i10000 $@
	@rm -rf test_extract
	@unzip mewnbeams-adventure.zip -d test_extract > /dev/null

report: mewnbeams-adventure.zip
	@echo '------------------------------------';
	@echo;
	@FILE_SIZE=$$(stat -c%s mewnbeams-adventure.zip 2>/dev/null || stat -f%z mewnbeams-adventure.zip); \
		PERCENT=$$(awk -v f="$$FILE_SIZE" -v t="13312" 'BEGIN { printf "%.3f", (f/t)*100 }'); \
		if (( $$(echo "$$PERCENT > 100" | bc -l) )); then \
			MESSAGE=$$(echo "🛑 TOO LARGE 🛑"); \
		else \
			MESSAGE=$$(echo "👍"); \
		fi; \
		echo "      $$FILE_SIZE / 13,312  =  $$PERCENT%  $$MESSAGE"; \
		echo "Prev: $$FILE_SIZE / 13,312  =  $$PERCENT%  $$MESSAGE  (from last committed)" > zipinfo.txt;
	-@git show HEAD:zipinfo.txt
	@FILE_SIZE=$$(stat -c%s dist/c.webp 2>/dev/null || stat -f%z dist/c.webp); \
		PERCENT=$$(awk -v f="$$FILE_SIZE" -v t="13312" 'BEGIN { printf "%.3f", (f/t)*100 }'); \
		echo "        * c.webp: $$FILE_SIZE (pre-zip)"
	@echo;
	@echo '------------------------------------';
