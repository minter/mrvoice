# This initializes the database
# Import it by running:
#
# mysql -u SUPERUSER_NAME -p YOUR_DATABASE < dbinit.sql
# 
# where SUPERUSER_NAME is the name of a user that can create tables
# within your database, and YOUR_DATABASE is the name of that database.

CREATE TABLE mrvoice (
   id int(8) NOT NULL auto_increment,
   title varchar(255) NOT NULL,
   artist varchar(255),
   category varchar(8) NOT NULL,
   info varchar(255),
   filename varchar(255) NOT NULL,
   modtime timestamp(6),
   PRIMARY KEY (id)
);

CREATE TABLE categories (
   code varchar(8) NOT NULL,
   description varchar(255) NOT NULL
);

INSERT INTO categories VALUES ('GEN','General Category');

#--
# CVS ID: $Id: dbinit.sql,v 1.4 2001/03/07 13:15:14 minter Exp $
