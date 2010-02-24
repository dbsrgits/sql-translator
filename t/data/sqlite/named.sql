create table pet (
  "pet_id" int,
  "person_id" int
    constraint fk_person_id references person(person_id),
  "name" varchar(30),
  "age" int,
  constraint age_under_100 check ( age < 100 ),
  constraint pk_pet primary key (pet_id, person_id)
);
