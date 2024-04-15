create table pet (
  "pet_id" int,
  "person_id" int,
  "name" varchar(30),
  "vet_visits" text not null check(json_valid(vet_visits) and json_type(vet_visits) = 'array') default '[]',
  constraint pk_pet primary key (pet_id, person_id)
);

create table zoo_animal (
    "pet_id" int,
    "person_id" int,
    "name" varchar(30),
    "vet_visits" text not null default '[]',
    constraint ck_json_array check(json_valid(vet_visits) and json_type(vet_visits) = 'array'),
    constraint pk_pet primary key (pet_id, person_id)
);
