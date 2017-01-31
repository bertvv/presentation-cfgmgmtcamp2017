## Presentation makefile
# This takes a Markdown file (PRESENTATION.md), and converts it to a
# Reveal.js slide deck using Pandoc.

#
# Variables
#

# Markdown file containing the presentation content
PRESENTATION := ansible-docker-testing

# Theme: black, moon, night, hogent
THEME := hogent

# Highlight styles: espresso or zenburn (not enough contrast in the others)
HIGHLIGHT_STYLE := haddock

# Directory where to put the resulting presentation
OUTPUT := gh-pages

# Directory for reveal.js
REVEAL_JS_DIR := $(OUTPUT)/reveal.js
THEME_FILE := $(REVEAL_JS_DIR)/css/theme/$(THEME).css

# File name of the reveal.js tarball
REVEAL_JS_TAR := 3.4.0.tar.gz

# Download URL
REVEAL_JS_URL := https://github.com/hakimel/reveal.js/archive/$(REVEAL_JS_TAR)

#
# Targets
#

all: $(THEME_FILE) $(OUTPUT)/index.html

## Generate Presentation
$(OUTPUT)/index.html: $(PRESENTATION).md $(REVEAL_JS_DIR) $(THEME_FILE)
	pandoc \
		--standalone \
		--to=revealjs \
		--template=default.revealjs \
		--variable=theme:$(THEME) \
		--highlight-style=$(HIGHLIGHT_STYLE) \
		--output $@ $<

## Copy theme file
$(THEME_FILE): $(THEME).css $(REVEAL_JS_DIR)
	cp $(THEME).css $(THEME_FILE)

## Download and install reveal.js locally
$(REVEAL_JS_DIR):
	wget $(REVEAL_JS_URL)
	tar xzf $(REVEAL_JS_TAR)
	rm $(REVEAL_JS_TAR)
	mv -T reveal.js* $(REVEAL_JS_DIR)

## Cleanup: remove the presentation and handouts
clean:
	rm -f $(OUTPUT)/*.html
	rm -f $(OUTPUT)/*.pdf

## Thorough cleanup (also removes reveal.js)
mrproper: clean
	rm -rf $(REVEAL_JS_DIR)

## Handouts in PDF
handouts.pdf: $(PRESENTATION).md
	pandoc --variable mainfont="DejaVu Sans" \
		--variable monofont="DejaVu Sans Mono" \
		--variable fontsize=11pt \
		--variable geometry:margin=1.5cm \
		-f markdown  $< \
		--latex-engine=lualatex \
		-o $@
