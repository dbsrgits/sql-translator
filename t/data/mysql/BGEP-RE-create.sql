##  MySQL dump 7.1
## 
##  Host: db1-3.23.32    Database: RE
## --------------------------------------------------------
##  Server version	3.23.32


##  Table structure for table 'ad' {{{
## 
DROP TABLE IF EXISTS ad;
CREATE TABLE ad (
## DROP TABLE IF EXISTS listing;
## CREATE TABLE listing (
  id varchar(32) DEFAULT '' NOT NULL,
  -- lid varchar(32) DEFAULT '' NOT NULL,
  vendor_id varchar(32) DEFAULT '' NOT NULL,
  -- lvid varchar(32) DEFAULT '' NOT NULL,
  realtor_id int(11) DEFAULT '0' NOT NULL,
  -- rid int(11) DEFAULT '0' NOT NULL,
  location_id int(11) DEFAULT '0' NOT NULL,
  -- lcid int(11) DEFAULT '0' NOT NULL,
  origin_id int(11) DEFAULT '0' NOT NULL,
  -- oid int(11) DEFAULT '0' NOT NULL,
  style_id int(11) DEFAULT '0' NOT NULL,
  -- sid int(11) DEFAULT '0' NOT NULL,
  style varchar(42) DEFAULT '' NOT NULL,
  media_code_id int(11) DEFAULT '0' NOT NULL,
  -- mcid int(11) DEFAULT '0' NOT NULL,
  priority int(11) DEFAULT '1' NOT NULL,
  listing_date date,
  price int(11) DEFAULT '0' NOT NULL,
  rooms int(11) DEFAULT '0' NOT NULL,
  bedrooms int(11) DEFAULT '0' NOT NULL,
  fullbaths int(11) DEFAULT '0' NOT NULL,
  halfbaths int(11) DEFAULT '0' NOT NULL,
  amenities varchar(255) DEFAULT '' NOT NULL,
  lotsize int(11) DEFAULT '0' NOT NULL,
  openhouse tinyint(4) DEFAULT '0' NOT NULL,
  street varchar(255) DEFAULT '' NOT NULL,
  no_units tinyint DEFAULT 1 NOT NULL,
  ad_text text,
  original_ad_text text,
  photo varchar(255) DEFAULT '' NOT NULL,
  thumbnail varchar(255) DEFAULT '' NOT NULL,
  PRIMARY KEY (id),
  -- PRIMARY KEY (lid),
  KEY vendor_id_idx (vendor_id),
  -- KEY vendor_id_idx (vid),
  KEY amenities_idx (amenities),
  KEY listing_date_idx (listing_date),
  FULLTEXT ad_text_search (ad_text)
);
## }}}

##  Table structure for table 'ad_to_amenity' {{{
## 
DROP TABLE IF EXISTS ad_to_amenity;
CREATE TABLE ad_to_amenity (
## CREATE TABLE listing_to_amenity (
  id int(11) NOT NULL auto_increment,
  -- aaid int(11) NOT NULL auto_increment,
  ad_id char(32) DEFAULT '' NOT NULL,
  -- lid char(32) DEFAULT '' NOT NULL,
  amenity_id int(11) DEFAULT '0' NOT NULL,
  -- aid int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (id),
  -- PRIMARY KEY (aaid),
  KEY ad_id_idx (ad_id)
  -- KEY ad_id_idx (lid)
);
## }}}

##  Table structure for table 'amenity' {{{
## 
DROP TABLE IF EXISTS amenity;
CREATE TABLE amenity (
  id int(11) NOT NULL auto_increment,
  -- aid int(11) NOT NULL auto_increment,
  amenity varchar(42) DEFAULT '' NOT NULL,
  abbrev varchar(4) DEFAULT '' NOT NULL,
  -- abbrev char(4) DEFAULT '' NOT NULL,
  PRIMARY KEY (id)
  -- PRIMARY KEY (aid)
);
## }}}

##  Table structure for table 'email' {{{
## 
DROP TABLE IF EXISTS email;
CREATE TABLE email (
  id int(11) NOT NULL auto_increment,
  -- eid int(11) NOT NULL auto_increment,
  realtor_id int(11) DEFAULT '0' NOT NULL,
  property_id int(11) DEFAULT '0' NOT NULL,
  firstname varchar(42) DEFAULT '' NOT NULL,
  lastname varchar(42) DEFAULT '' NOT NULL,
  phone varchar(10) DEFAULT '' NOT NULL,
  timeframe varchar(255) DEFAULT '' NOT NULL,
  schedule_appt tinyint(4) DEFAULT '0' NOT NULL,
  date_sent timestamp(14),
  comments text,
  PRIMARY KEY (id)
  -- PRIMARY KEY (eid)
);
## }}}

##  Table structure for table 'history' {{{
## 
DROP TABLE IF EXISTS history;
CREATE TABLE history (
  id int(11) NOT NULL auto_increment,
  -- hid int(11) NOT NULL auto_increment,
  type varchar(42) DEFAULT '' NOT NULL,
  value varchar(255) DEFAULT '' NOT NULL,
  ts timestamp(14),
  PRIMARY KEY (id)
  -- PRIMARY KEY (hid)
);
## }}}

##  Table structure for table 'location' {{{
## 
DROP TABLE IF EXISTS location;
CREATE TABLE location (
  id int(11) NOT NULL auto_increment,
  -- lcid int(11) NOT NULL auto_increment,
  abbrev varchar(4) DEFAULT '' NOT NULL,
  city varchar(42) DEFAULT '' NOT NULL,
  state char(2) DEFAULT 'MA' NOT NULL,
  fullstate varchar(42) DEFAULT 'Massachusetts' NOT NULL,
  PRIMARY KEY (id),
  -- PRIMARY KEY (lcid),
  KEY city_idx (city),
  KEY abbrev_idx (abbrev),
  KEY state_idx (state)
);
## }}}

##  Table structure for table 'media_code' {{{
## 
DROP TABLE IF EXISTS media_code;
CREATE TABLE media_code (
## DROP TABLE IF EXISTS mediacode;
## CREATE TABLE mediacode ( -- should this table be category?
  media_code int(11) DEFAULT '700' NOT NULL,
  -- mcid int(11) DEFAULT '700' NOT NULL,
  classification varchar(42) DEFAULT '' NOT NULL,
  PRIMARY KEY (media_code)
  -- PRIMARY KEY (mcid)
);
## }}}

##  Table structure for table 'origin' {{{
## 
DROP TABLE IF EXISTS origin;
CREATE TABLE origin (
  id int(11) NOT NULL auto_increment,
  -- oid int(11) NOT NULL auto_increment,
  origin varchar(24) DEFAULT '' NOT NULL,
  display varchar(42) DEFAULT '' NOT NULL,
  PRIMARY KEY (id)
  -- PRIMARY KEY (oid)
);
## }}}

##  Table structure for table 'realtor' {{{
## 
DROP TABLE IF EXISTS realtor;
CREATE TABLE realtor (
  id int(11) NOT NULL auto_increment,
  -- rid int(11) NOT NULL auto_increment,
  vendor_id varchar(6) DEFAULT '' NOT NULL,
  -- rvid varchar(6) DEFAULT '' NOT NULL,
  name varchar(255) DEFAULT '' NOT NULL,
  phone varchar(24) DEFAULT '' NOT NULL,
  location_id int(11) DEFAULT '0' NOT NULL,
  -- lcid int(11) DEFAULT '0' NOT NULL,
  email varchar(255) DEFAULT '' NOT NULL,
  url varchar(255) DEFAULT '' NOT NULL,
  tagline text,
  logo_url varchar(255) DEFAULT '' NOT NULL,
  upsell tinyint(4) DEFAULT '0',
  start_date date,
  end_date date,
  PRIMARY KEY (id),
  -- PRIMARY KEY (vid),
  KEY name_idx (name),
  KEY phone_idx (phone)
);
## }}}

##  Table structure for table 'style' {{{
## 
DROP TABLE IF EXISTS style;
CREATE TABLE style (
  id int(11) NOT NULL auto_increment,
  -- sid int(11) NOT NULL auto_increment,
  style varchar(42) DEFAULT '' NOT NULL,
  abbrev varchar(42) DEFAULT '' NOT NULL,
  PRIMARY KEY (id),
  -- PRIMARY KEY (sid),
  KEY style_idx (style)
);
## }}}





