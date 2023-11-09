PDF_PARAMS=-s --pdf-engine=xelatex -V lang=en -V documentclass=scrartcl -V papersize=a4
FONTS=-V mainfont="Crimson Pro" -V sansfont="Lato" -V monofont="Fantasque Sans Mono"
DATE=-V date="`date +'%Y-%m-%d'`"

elixir-concurrency-using-prime-factorization.pdf: article.md
	pandoc $(PDF_PARAMS) $(FONTS) $(DATE) $^ -o $@
