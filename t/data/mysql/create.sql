create table person (
  person_id INTEGER PRIMARY KEY,
  name varchar(20),
  age integer,
  weight double(11,2),
  iq tinyint default '0',
  description text
) ENGINE=MyISAM;

create unique index u_name on person (name);
