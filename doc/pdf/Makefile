# CVS ID: $Id: Makefile,v 1.1 2001/12/21 19:15:49 minter Exp $

all:    mrvoice.pdf

mrvoice.pdf :  $(CHAPTERS)
	openjade -t tex -d $(PDF_STYLESHEET) -o $(BOOK).tex -V nochunks ../sgml/$(BOOK).sgml
	pdfjadetex $(BOOK).tex
	pdfjadetex $(BOOK).tex
	pdfjadetex $(BOOK).tex
