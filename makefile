.PHONY: css
css:
	./node_modules/.bin/postcss source/css/source.css --use postcss-import --use precss --use --postcss-extend-rule --use --postcss-nested --use autoprefixer --use cssnano --no-map --output source/css/fans.css

.PHONY: copy
copy:
	mkdir -p ../hexo-theme-unit-test/themes/fans
	cp -r ./layout ../hexo-theme-unit-test/themes/fans/
	cp -r ./source ../hexo-theme-unit-test/themes/fans/
	cp -r ./languages ../hexo-theme-unit-test/themes/fans/
	cp -r ./_config.yml ../hexo-theme-unit-test/themes/fans/


.PHONY: all
all:
	make css
	make copy
