create table a (
	a_id serial not null,
	primary key (a_id),
	b_id int not null,
	foreign key (b_id) references b (b_id),
	name text
);

--create table b (
--	b_id serial not null,
--	primary key (b_id),
--	name text
--);

--create table a_b (
--	a_b_id serial not null,
--	primary key (a_b_id),
--	a_id int not null,
--	foreign key (a_id) references a (a_id),
--	b_id int not null,
--	foreign key (b_id) references b (b_id)
--);

--create table c (
--	c_id serial not null,
--	primary key (c_id),
--	b_id int not null,
--	foreign key (b_id) references b (b_id),
--	name text
--);

--create table d (
--	d_id serial not null,
--	primary key (d_id),
--	c_id int not null,
--	foreign key (c_id) references c (c_id),
--	name text
--);

create table e (
	e_id serial not null,
	primary key (e_id),
	name text
);

--create table c_e (
--	c_e_id serial not null,
--	primary key (c_e_id),
--	c_id int not null,
--	foreign key (c_id) references c (c_id),
--	e_id int not null,
--	foreign key (e_id) references e (e_id)
--);

--create table f (
--	f_id serial not null,
--	primary key (f_id),
--	e1_id int not null,
--	foreign key (e1_id) references e (e_id),
--	e2_id int not null,
--	foreign key (e2_id) references e (e_id)
--);

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

--create table h (
--	h_id serial not null,
--	primary key (h_id),
--	a1_id int not null,
--	foreign key (a1_id) references a (a_id),
--	a2_id int not null,
--	foreign key (a2_id) references a (a_id),
--	g1_id int not null,
--	foreign key (g1_id) references g (g_id),
--	g2_id int not null,
--	foreign key (g2_id) references g (g_id)
--);
