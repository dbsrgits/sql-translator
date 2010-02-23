create table person (
  person_id INTEGER PRIMARY KEY,
  name varchar(20),
  age integer,
  weight double(11,2),
  iq tinyint default '0',
  description text,
  UNIQUE KEY UC_age_name (age)
) ENGINE=MyISAM;

create unique index u_name on person (name);

create table employee (
	position varchar(50),
	employee_id integer,
  job_title varchar(255),
	CONSTRAINT FK5302D47D93FE702E FOREIGN KEY (employee_id) REFERENCES person (person_id),
	PRIMARY KEY  (position, employee_id) USING BTREE
) ENGINE=InnoDB;

create table deleted (
  id integer
);
