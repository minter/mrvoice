# This initializes the database
# Import it by running:
# mysql -u SUPERUSER_NAME -p YOUR_DATABASE < dbinit.sql

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
# CVS ID: $Id: dbinit.sql,v 1.3 2001/02/21 03:01:46 minter Exp $
