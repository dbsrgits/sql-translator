-- 1 single FK import, data table
create table a (
	a_id serial not null,
	primary key (a_id),
	b_id int not null,
	foreign key (b_id) references b (b_id),
	name text
);

-- standalone, data table
create table b (
	b_id serial not null,
	primary key (b_id),
	name text
);

-- 1 single FK import, link table between 'a' and 'b'
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

-- 1 double FK import, 1 triple FK import, link table between 'a', 'a', 'g', 'g', and 'g'
create table h (
	h_id serial not null,
	primary key (h_id),
	a1_id int not null,
	foreign key (a1_id) references a (a_id),
	a2_id int not null,
	foreign key (a2_id) references a (a_id),
	g1_id int not null,
	foreign key (g1_id) references g (g_id),
	g2_id int not null,
	foreign key (g2_id) references g (g_id),
	g3_id int not null,
	foreign key (g3_id) references g (g_id)
);

