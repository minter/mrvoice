# CVS ID: $Id: Makefile,v 1.2 2001/12/22 14:38:42 minter Exp $

all:	mrvoice.html index.htm

mrvoice.html :	$(CHAPTERS)
	openjade -t sgml -d $(HTML_STYLESHEET) -V nochunks ../sgml/$(BOOK).sgml > $(BOOK).html

index.htm :	$(CHAPTERS)
	openjade -t sgml -V%root-filename%="index" -d $(HTML_STYLESHEET) ../sgml/$(BOOK).sgml
