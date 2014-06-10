.PHONY: compile clean watch

compile:
	@node_modules/.bin/coffee -c -o . src

clean:
	@rm -rf lib

watch:
	@node_modules/.bin/coffee -cw -o . src

