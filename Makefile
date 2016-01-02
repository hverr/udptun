.PHONY: all

PNG_TARGETS=\
	one-to-many.png

PDF_TARGETS=$(PNG_TARGETS:.png=.pdf)

TEX_TARGETS=$(PDF_TARGETS:.pdf=.tex)

all: $(PNG_TARGETS)

%.png: %.pdf
	convert $< $@

%.pdf: %.tex
	pdflatex $<
