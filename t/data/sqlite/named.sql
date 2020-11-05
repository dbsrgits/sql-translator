create table pet (
  "pet_id" int,
  "person_id" int
    constraint fk_person_id references person(person_id) on update CASCADE on delete RESTRICT,
  "person_id_2" int
    constraint fk_person_id_2 references person(person_id) on update SET NULL on delete SET DEFAULT,
  "person_id_3" int
    constraint fk_person_id_3 references person(person_id) on update NO ACTION,
  "name" varchar(30),
  "age" int,
  constraint age_under_100 check ( age < 100 and age not in (101, 102) ),
  constraint pk_pet primary key (pet_id, person_id)
);
