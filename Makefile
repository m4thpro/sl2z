all: quantized-title.png

title.pdf: title.tex
	pdflatex title.tex

title.png: title.pdf
	mutool draw -r 128 -o title.png title.pdf

inverted-title.png: title.png
	convert -negate title.png inverted-title.png

quantized-title.png: inverted-title.png
	convert inverted-title.png -dither None -remap pico-palette.png quantized-title.png

