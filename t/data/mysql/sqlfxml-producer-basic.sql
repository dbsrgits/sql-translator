-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Aug  7 16:28:01 2003
-- 
-- SET foreign_key_checks=0;

--
-- Table: Basic
--
CREATE TABLE Basic (
    -- comment on id field
    id integer(10) NOT NULL auto_increment
   ,title varchar(100) NOT NULL DEFAULT 'hello'
   ,description text DEFAULT ''
   ,email varchar(255)
   ,INDEX  titleindex (title)
   ,PRIMARY KEY (id)
   ,UNIQUE (email)
);

