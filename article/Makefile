PARAMS=-N -V lang=en -V linkcolor=darkblue
PDF_PARAMS=-s --pdf-engine=xelatex -V documentclass=scrartcl -V papersize=a4
FONTS=-V mainfont="Crimson Pro" -V sansfont="Lato" -V monofont="Fantasque Sans Mono"
DATE=-V date="`date +'%Y-%m-%d'`"

.PHONY: all clean

all: article.pdf article.docx

article.pdf: article.md
	pandoc $(PARAMS) $(PDF_PARAMS) $(FONTS) $(DATE) $^ -o $@

article.docx: article.md
	pandoc $(PARAMS) $(DATE) $^ -o $@

clean: rm -f $(all)
