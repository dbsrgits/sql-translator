-- standalone, data table
create table b (
	b_id serial not null,
	primary key (b_id),
	name text
);

-- 1 single FK import, data table
create table a (
	a_id serial not null,
	primary key (a_id),
	b_id int not null,
	foreign key (b_id) references b (b_id),
	name text
);

-- 2 single FK import, link table between 'a' and 'b'
-- note that 'a' both imports a FK from 'b', as well as links to 'b' via 'a_b'
create table a_b (
	a_b_id serial not null,
	primary key (a_b_id),
	a_id int not null,
	foreign key (a_id) references a (a_id),
	b_id int not null,
	foreign key (b_id) references b (b_id)
);

-- 1 single FK import, data table
create table c (
	c_id serial not null,
	primary key (c_id),
	b_id int not null,
	foreign key (b_id) references b (b_id),
	name text
);

-- 1 single FK import, data table
create table d (
	d_id serial not null,
	primary key (d_id),
	c_id int not null,
	foreign key (c_id) references c (c_id),
	name text
);

-- standalone, data table
create table e (
	e_id serial not null,
	primary key (e_id),
	name text
);

-- 2 single FK import, link table between 'c' and 'e'
create table c_e (
	c_e_id serial not null,
	primary key (c_e_id),
	c_id int not null,
	foreign key (c_id) references c (c_id),
	e_id int not null,
	foreign key (e_id) references e (e_id)
);

-- 1 triple FK import, link table between 'e', 'e', and 'e'
create table f (
	f_id serial not null,
	primary key (f_id),
	e1_id int not null,
	foreign key (e1_id) references e (e_id),
	e2_id int not null,
	foreign key (e2_id) references e (e_id),
	e3_id int not null,
	foreign key (e3_id) references e (e_id)
);

-- 1 single FK import, 1 double FK import, link table between 'a', 'e', and 'e'
create table g (
	g_id serial not null,
	primary key (g_id),
	a_id int not null,
	foreign key (a_id) references a (a_id),
	e1_id int not null,
	foreign key (e1_id) references e (e_id),
	e2_id int not null,
	foreign key (e2_id) references e (e_id)
);

-- 1 double FK import, 1 triple FK import, link table between 'a', 'a', 'e', 'e', and 'e'
create table h (
	h_id serial not null,
	primary key (h_id),
	a1_id int not null,
	foreign key (a1_id) references a (a_id),
	a2_id int not null,
	foreign key (a2_id) references a (a_id),
	e1_id int not null,
	foreign key (e1_id) references e (e_id),
	e2_id int not null,
	foreign key (e2_id) references e (e_id),
	e3_id int not null,
	foreign key (e3_id) references e (e_id)
);

-- 3 single FK import, link table between 'b', 'c', and 'd'
create table i (
	i_id serial not null,
	primary key (i_id),
	b_id int not null,
	foreign key (b_id) references b (b_id),
	c_id int not null,
	foreign key (c_id) references c (c_id),
	d_id int not null,
	foreign key (d_id) references d (d_id)
);

insert into b   (name)                          values ('balloon');
insert into b   (name)                          values ('bangup');
insert into b   (name)                          values ('beluga');
insert into b   (name)                          values ('blanch');
insert into b   (name)                          values ('botch');
insert into b   (name)                          values ('brooch');
insert into b   (name)                          values ('broccoli');
insert into b   (name)                          values ('blitz');
insert into b   (name)                          values ('blintz');
insert into a   (name,b_id)                     values ('alkane',1);
insert into a   (name,b_id)                     values ('alkyne',2);
insert into a   (name,b_id)                     values ('amygdala',3);
insert into a   (name,b_id)                     values ('aorta',4);
insert into a_b (a_id,b_id)                     values (1,5);
insert into c   (name,b_id)                     values ('cairn',6);
insert into c   (name,b_id)                     values ('cootie',7);
insert into c   (name,b_id)                     values ('cochlea',8);
insert into d   (name,c_id)                     values ('drake',1);
insert into e   (name)                          values ('ear');
insert into e   (name)                          values ('element');
insert into e   (name)                          values ('embryo');
insert into e   (name)                          values ('encumber');
insert into e   (name)                          values ('enhance');
insert into e   (name)                          values ('ependyma');
insert into e   (name)                          values ('epididymis');
insert into e   (name)                          values ('ergot');
insert into e   (name)                          values ('esophagus');
insert into c_e (c_id,e_id)                     values (2,1);
insert into f   (e1_id,e2_id,e3_id)             values (2,3,4);
insert into g   (a_id,e1_id,e2_id)              values (2,5,6);
insert into h   (a1_id,a2_id,e1_id,e2_id,e3_id) values (3,4,7,8,9);
insert into i   (b_id,c_id,d_id)                values (9,3,1);
