# CVS ID: $Id: Makefile,v 1.3 2002/04/17 01:57:47 minter Exp $

all:	mrvoice.html index.htm

mrvoice.html :	$(CHAPTERS)
	docbook2html -u ../sgml/$(BOOK).sgml
#	openjade -t sgml -d $(HTML_STYLESHEET) -V nochunks ../sgml/$(BOOK).sgml > $(BOOK).html

index.htm :	$(CHAPTERS)
	docbook2html -V %root-filename%="index" ../sgml/$(BOOK).sgml
#	openjade -t sgml -V%root-filename%="index" -d $(HTML_STYLESHEET) ../sgml/$(BOOK).sgml
