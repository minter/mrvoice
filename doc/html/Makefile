# CVS ID: $Id: Makefile,v 1.1 2001/12/21 19:15:49 minter Exp $

all:	mrvoice.html multi-html

mrvoice.html :	$(CHAPTERS)
	openjade -t sgml -d $(HTML_STYLESHEET) -V nochunks ../sgml/$(BOOK).sgml > $(BOOK).html

multi-html :	$(CHAPTERS)
	openjade -t sgml -V%root-filename%="index" -d $(HTML_STYLESHEET) ../sgml/$(BOOK).sgml
