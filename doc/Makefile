# SVN ID: $Id$

# Define Variables
export BOOK := mrvoice
export HTML_STYLESHEET := /usr/share/sgml/docbook/dsssl-stylesheets-1.79/html/docbook.dsl
export PDF_STYLESHEET := /usr/share/sgml/docbook/dsssl-stylesheets-1.79/print/docbook.dsl
export CHAPTERS := ../sgml/mrvoice.sgml ../sgml/installing-mrvoice.sgml ../sgml/using-mrvoice.sgml ../sgml/config-mrvoice.sgml ../sgml/mrvoice-online.sgml

all:	html pdf

check:	sgml/$(BOOK).sgml
	@echo "--> Checking SGML syntax with nsgmls"
	nsgmls -sv sgml/$(BOOK).sgml 

html:	check
	@cd html; make all

pdf:	check 
	@cd pdf; make all

clean:
	-rm pdf/$(BOOK).pdf
	-rm html/$(BOOK).html
	-rm html/*.html
