CREATE TABLE ad (
  id varchar(32) NOT NULL DEFAULT '',
  vendor_id varchar(32) NOT NULL DEFAULT '',
  realtor_id int(11) NOT NULL DEFAULT 0,
  location_id int(11) NOT NULL DEFAULT 0,
  origin_id int(11) NOT NULL DEFAULT 0,
  style_id int(11) NOT NULL DEFAULT 0,
  style varchar(42) NOT NULL DEFAULT '',
  media_code_id int(11) NOT NULL DEFAULT 0,
  priority int(11) NOT NULL DEFAULT 1,
  listing_date date,
  price int(11) NOT NULL DEFAULT 0,
  rooms int(11) NOT NULL DEFAULT 0,
  bedrooms int(11) NOT NULL DEFAULT 0,
  fullbaths int(11) NOT NULL DEFAULT 0,
  halfbaths int(11) NOT NULL DEFAULT 0,
  amenities varchar(255) NOT NULL DEFAULT '',
  lotsize int(11) NOT NULL DEFAULT 0,
  openhouse tinyint(4) NOT NULL DEFAULT 0,
  street varchar(255) NOT NULL DEFAULT '',
  no_units tinyint NOT NULL DEFAULT 1,
  ad_text text,
  original_ad_text text,
  photo varchar(255) NOT NULL DEFAULT '',
  thumbnail varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  KEY vendor_id_idx (vendor_id),
  KEY amenities_idx (amenities),
  KEY listing_date_idx (listing_date)
);

CREATE TABLE ad_to_amenity (
  id int(11) NOT NULL auto_increment,
  ad_id char(32) NOT NULL DEFAULT '',
  amenity_id int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY ad_id_idx (ad_id)
);

CREATE TABLE amenity (
  id int(11) NOT NULL auto_increment,
  amenity varchar(42) NOT NULL DEFAULT '',
  abbrev varchar(4) NOT NULL DEFAULT '',
  PRIMARY KEY (id)
);

CREATE TABLE email (
  id int(11) NOT NULL auto_increment,
  realtor_id int(11) NOT NULL DEFAULT 0,
  property_id int(11) NOT NULL DEFAULT 0,
  firstname varchar(42) NOT NULL DEFAULT '',
  lastname varchar(42) NOT NULL DEFAULT '',
  phone varchar(10) NOT NULL DEFAULT '',
  timeframe varchar(255) NOT NULL DEFAULT '',
  schedule_appt tinyint(4) NOT NULL DEFAULT 0,
  date_sent timestamp(14),
  comments text,
  PRIMARY KEY (id)
);

CREATE TABLE history (
  id int(11) NOT NULL auto_increment,
  type varchar(42) NOT NULL DEFAULT '',
  value varchar(255) NOT NULL DEFAULT '',
  ts timestamp(14),
  PRIMARY KEY (id)
);

CREATE TABLE location (
  id int(11) NOT NULL auto_increment,
  abbrev varchar(4) NOT NULL DEFAULT '',
  city varchar(42) NOT NULL DEFAULT '',
  state char(2) NOT NULL DEFAULT 'MA',
  fullstate varchar(42) NOT NULL DEFAULT 'Massachusetts',
  PRIMARY KEY (id),
  KEY city_idx (city),
  KEY abbrev_idx (abbrev),
  KEY state_idx (state)
);

CREATE TABLE mediacode ( 
  media_code int(11) NOT NULL DEFAULT 700,
  classification varchar(42) NOT NULL DEFAULT '',
  PRIMARY KEY (media_code)
);

CREATE TABLE origin (
  id int(11) NOT NULL auto_increment,
  origin varchar(24) NOT NULL DEFAULT '',
  display varchar(42) NOT NULL DEFAULT '',
  PRIMARY KEY (id)
);

CREATE TABLE realtor (
  id int(11) NOT NULL auto_increment,
  vendor_id varchar(6) NOT NULL DEFAULT '',
  name varchar(255) NOT NULL DEFAULT '',
  phone varchar(24) NOT NULL DEFAULT '',
  location_id int(11) NOT NULL DEFAULT 0,
  email varchar(255) NOT NULL DEFAULT '',
  url varchar(255) NOT NULL DEFAULT '',
  tagline text,
  logo_url varchar(255) NOT NULL DEFAULT '',
  upsell tinyint(4) DEFAULT 0,
  start_date date,
  end_date date,
  PRIMARY KEY (id),
  KEY name_idx (name),
  KEY phone_idx (phone)
);

CREATE TABLE style (
  id int(11) NOT NULL auto_increment,
  style varchar(42) NOT NULL DEFAULT '',
  abbrev varchar(42) NOT NULL DEFAULT '',
  PRIMARY KEY (id),
  KEY style_idx (style)
);
