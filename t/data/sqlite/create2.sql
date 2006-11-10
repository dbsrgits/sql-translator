create table person (
  person_id INTEGER PRIMARY KEY,
  name varchar(20) not null,
  age integer,
  weight double(11,2),
  iq int default '0',
  is_rock_star tinyint default '1',
  description text
);

create unique index u_name on person (name);

create table pet (
  pet_id int,
  person_id int,
  name varchar(30),
  age int,
  check ( age < 100 ),
  primary key (pet_id, person_id)
);

create trigger after insert on pet 
  begin
    update pet set name=name;
  end
;

create view person_pet as
  select pr.person_id, pr.name as person_name, pt.name as pet_name
  from   person pr, pet pt
  where  person.person_id=pet.pet_id
;
