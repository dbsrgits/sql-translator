create table person (
  person_id INTEGER PRIMARY KEY AUTO_INCREMENT,
  name varchar(20) not null,
  age integer default '18',
  weight double(11,2),
  iq int default '0',
  is_rock_star tinyint default '1',
  physical_description text,
  UNIQUE KEY UC_person_id (person_id),
  UNIQUE KEY UC_age_name (age, name)
) ENGINE=InnoDB;

create unique index unique_name on person (name);

create table employee (
	position varchar(50),
	employee_id INTEGER,
	CONSTRAINT FK5302D47D93FE702E_diff FOREIGN KEY (employee_id) REFERENCES person (person_id),
	CONSTRAINT `demo_constraint` CHECK (`employee_id` > 0 and `employee_id` IS NOT NULL and `employee_id` not in (0)),
	PRIMARY KEY  (employee_id, position)
) ENGINE=InnoDB;

create table added (
  id integer
);

