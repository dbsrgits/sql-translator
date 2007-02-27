create table person (
  person_id INTEGER PRIMARY KEY,
  name varchar(20),
  age integer,
  weight double(11,2),
  iq tinyint default '0',
  description text
) ENGINE=MyISAM;

create unique index u_name on person (name);

create table employee (
	position varchar(50),
	employee_id integer,
	CONSTRAINT FK5302D47D93FE702E FOREIGN KEY (employee_id) REFERENCES person (person_id),
	PRIMARY KEY  (position, employee_id)
) ENGINE=InnoDB;

