-- $Header: /home/faga/work/sqlfairy_svn/sqlfairy-cvsbackup/sqlfairy/t/data/pgsql/entire_syntax.sql,v 1.1 2003-08-17 00:42:57 rossta Exp $

-- done:

-- smallint int2 signed two-byte integer 
-- integer int, int4 signed four-byte integer 
-- bigint int8 signed eight-byte integer 
-- serial serial4 autoincrementing four-byte integer 
-- bigserial serial8 autoincrementing eight-byte integer 

-- real float4 single precision floating-point number 
-- double precision float8 double precision floating-point number 

-- numeric [ (p, s) ] decimal [ (p, s) ] exact numeric with selectable precision 

-- character(n) char(n) fixed-length character string 
-- character varying(n) varchar(n) variable-length character string 

-- date   calendar date (year, month, day) 

-- time [ (p) ] [ without time zone ]   time of day 
-- time [ (p) ] with time zone timetz time of day, including time zone 

-- timestamp [ (p) ] without time zone timestamp date and time 
-- timestamp [ (p) ] [ with time zone ] timestamptz date and time, including time zone 

-- bytea   binary data 

-- text   variable-length character string 

-- to do:

-- bit   fixed-length bit string 
-- bit varying(n) varbit(n) variable-length bit string 
-- boolean bool logical Boolean (true/false) 
-- box   rectangular box in 2D plane 
-- cidr   IP network address 
-- circle   circle in 2D plane 
-- inet   IP host address 
-- interval(p)   general-use time span 
-- line   infinite line in 2D plane (not implemented) 
-- lseg   line segment in 2D plane 
-- macaddr   MAC address 
-- money   currency amount 
-- path   open and closed geometric path in 2D plane 
-- point   geometric point in 2D plane 
-- polygon   closed geometric path in 2D plane 

-- Compatibility: The following types (or spellings thereof) are specified by SQL:
-- bit, bit varying, boolean, char, character, character varying, varchar, date, 
-- double precision, integer, interval, numeric, decimal, real, smallint, time,
-- timestamp (both with or without time zone). 

CREATE TABLE t01 (
	i01 SMALLINT,
	i02 INT2,
	i03 INT,
	i04 INTEGER,
	i05 INT4,
	i06 BIGINT,
	i07 INT8,
	i08 SERIAL,
	i09 SERIAL4,
	i10 BIGSERIAL,
	i11 SERIAL8,

	r01 REAL,
	r02 FLOAT4,
	r03 DOUBLE PRECISION,
	r04 FLOAT,
	r05 FLOAT8,
	
	n01 DECIMAL,
	n02 NUMERIC,

	c01 CHAR(10),
	c02 VARCHAR(10),
	c03 CHARACTER(10),
	c04 CHARACTER VARYING(10),

	d01 DATE,
	d02 TIME,
	d03 TIMETZ,
	d04 TIMESTAMP,
	d05 TIMESTAMPTZ,

	b01 BYTEA,

	t01 TEXT
);
