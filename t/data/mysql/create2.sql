create table person (
  person_id INTEGER PRIMARY KEY AUTO_INCREMENT,
  name varchar(20) not null,
  age integer default '18',
  weight double(11,2),
  iq int default '0',
  is_rock_star tinyint default '1',
  description text,
  UNIQUE KEY UC_person_id (person_id)
) ENGINE=InnoDB;

create unique index u_name on person (name);

create table employee (
	position varchar(50),
	employee_id INTEGER,
	CONSTRAINT FK5302D47D93FE702E_diff FOREIGN KEY (employee_id) REFERENCES person (person_id)
) ENGINE=InnoDB;
