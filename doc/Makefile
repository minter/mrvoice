# CVS ID: $Id: Makefile,v 1.1 2001/12/21 19:15:03 minter Exp $

# Define Variables
export BOOK := mrvoice
export HTML_STYLESHEET := /usr/local/share/sgml/docbook/dsssl/modular/html/docbook.dsl
export PDF_STYLESHEET := /usr/local/share/sgml/docbook/dsssl/cygnus/cygnus-both.dsl
export CHAPTERS := ../sgml/mrvoice.sgml ../sgml/installing-mrvoice.sgml ../sgml/using-mrvoice.sgml ../sgml/config-mrvoice.sgml

all:	html pdf clean

check:	sgml/$(BOOK).sgml
	@echo "--> Checking SGML syntax with nsgmls"
	nsgmls -sv sgml/$(BOOK).sgml 

html:	check
	@cd html; make all

pdf:	check 
	@cd pdf; make all

rtf:	check $(BOOK).sgml
	openjade -t rtf -d $(STYLESHEET_DIR)/print/docbook.dsl $(BOOK).sgml

clean:
	-rm pdf/$(BOOK).log
	-rm pdf/$(BOOK).aux
	-rm pdf/$(BOOK).tex
	-rm pdf/$(BOOK).out

realclean:	clean
	-rm pdf/$(BOOK).pdf
	-rm html/$(BOOK).html
	-rm html/*.htm
