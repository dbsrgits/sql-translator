DROP TABLE div_aa_annotation;
CREATE TABLE div_aa_annotation
 (
	div_aa_annotation_id			Long Integer (4), 
	div_annotation_type_id			Long Integer (4), 
	div_allele_assay_id			Long Integer (4), 
	annotation_value			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_allele;
CREATE TABLE div_allele
 (
	div_allele_id			Long Integer (4), 
	div_obs_unit_sample_id			Long Integer (4), 
	div_allele_assay_id			Long Integer (4), 
	allele_num			Long Integer (4), 
	quality			Long Integer (4), 
	value			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_allele_assay;
CREATE TABLE div_allele_assay
 (
	div_allele_assay_id			Long Integer (4), 
	div_marker_id			Long Integer (4), 
	div_poly_type_id			Long Integer (4), 
	comments			Text (50), 
	date			DateTime (Short) (8), 
	name			Text (50), 
	phase_determined			Text (50), 
	producer			Text (50), 
	position			Text (50), 
	ref_seq			Text (50), 
	div_ref_stock_id			Long Integer (4), 
	source_assay			Text (50), 
	length			Long Integer (4)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_annotation_type;
CREATE TABLE div_annotation_type
 (
	div_annotation_type_id			Long Integer (4), 
	anno_type			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_exp_entry;
CREATE TABLE div_exp_entry
 (
	div_exp_entry_id			Long Integer (4), 
	div_experiment_id			Long Integer (4), 
	div_obsunit_id			Long Integer (4), 
	div_stock_id			Long Integer (4), 
	plant			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_experiment;
CREATE TABLE div_experiment
 (
	div_experiment_id			Long Integer (4), 
	name			Text (50), 
	design			Text (50), 
	originator			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_generation;
CREATE TABLE div_generation
 (
	div_generation_id			Long Integer (4), 
	value			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_locality;
CREATE TABLE div_locality
 (
	div_locality_id			Long Integer (4), 
	elevation			Long Integer (4), 
	city			Text (50), 
	country			Text (50), 
	origcty			Text (50), 
	latitude			Long Integer (4), 
	longitude			Long Integer (4), 
	locality_name			Text (50), 
	state_province			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_locus;
CREATE TABLE div_locus
 (
	div_locus_id			Long Integer (4), 
	chromosome_number			Long Integer (4), 
	comments			Text (50), 
	genetic_bin			Text (50), 
	genetic_map			Text (50), 
	genetic_position			Long Integer (4), 
	locus_type			Text (50), 
	name			Text (50), 
	physical_position			Long Integer (4)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_marker;
CREATE TABLE div_marker
 (
	div_marker_id			Long Integer (4), 
	div_locus_id			Long Integer (4), 
	name			Text (50), 
	ref_seq			Text (50), 
	div_ref_stock_id			Long Integer (4)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_obs_unit;
CREATE TABLE div_obs_unit
 (
	div_obs_unit_id			Long Integer (4), 
	div_experiment_id			Long Integer (4), 
	div_stock_id			Long Integer (4), 
	div_locality_id			Long Integer (4), 
	name			Text (50), 
	field_coord_x			Long Integer (4), 
	field_coord_y			Long Integer (4), 
	rep			Long Integer (4), 
	block			Long Integer (4), 
	plot			Long Integer (4), 
	plant			Text (50), 
	planting_date			DateTime (Short) (8), 
	harvest_date			DateTime (Short) (8), 
	summary			Boolean

);
-- CREATE ANY INDEXES ...

DROP TABLE div_obs_unit_sample;
CREATE TABLE div_obs_unit_sample
 (
	div_obs_unit_sample_id			Long Integer (4), 
	div_obs_unit_id			Long Integer (4), 
	date			DateTime (Short) (8), 
	name			Text (50), 
	producer			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_passport;
CREATE TABLE div_passport
 (
	div_passport_id			Long Integer (4), 
	div_locality_id			Long Integer (4), 
	accename			Text (50), 
	collnumb			Long Integer (4), 
	collector			Text (50), 
	remarks			Text (50), 
	genus			Text (50), 
	germplasm_type			Text (50), 
	local_name			Text (50), 
	population			Text (50), 
	race_name			Text (50), 
	reference			Text (50), 
	secondary_source			Text (50), 
	source			Text (50), 
	species			Text (50), 
	subspecies			Text (50), 
	instcode			Text (50), 
	accenumb			Long Integer (4), 
	collcode			Text (50), 
	spauthor			Text (50), 
	subtaxa			Text (50), 
	subtauthor			Text (50), 
	cropname			Text (50), 
	acqdate			DateTime (Short) (8), 
	colldate			DateTime (Short) (8), 
	bredcode			Text (50), 
	sampstat			Text (50), 
	collsrc			Text (50), 
	donorcode			Text (50), 
	donornumb			Long Integer (4), 
	othernumb			Long Integer (4), 
	duplsite			Text (50), 
	storage			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_poly_type;
CREATE TABLE div_poly_type
 (
	div_poly_type_id			Long Integer (4), 
	poly_type			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_statistic_type;
CREATE TABLE div_statistic_type
 (
	div_statistic_type_id			Long Integer (4), 
	stat_type			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_stock;
CREATE TABLE div_stock
 (
	div_stock_id			Long Integer (4), 
	div_generation_id			Long Integer (4), 
	div_passport_id			Long Integer (4), 
	seed_lot			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_stock_parent;
CREATE TABLE div_stock_parent
 (
	div_stock_parent_id			Long Integer (4), 
	div_stock_id			Long Integer (4), 
	div_parent_id			Long Integer (4), 
	recurrent			Boolean, 
	role			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_trait;
CREATE TABLE div_trait
 (
	div_trait_id			Long Integer (4), 
	div_trait_uom_id			Long Integer (4), 
	div_statistic_type_id			Long Integer (4), 
	div_obs_unit_id			Long Integer (4), 
	date			DateTime (Short) (8), 
	value			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_trait_uom;
CREATE TABLE div_trait_uom
 (
	div_trait_uom_id			Long Integer (4), 
	qtl_trait_ontology_id			Long Integer (4), 
	div_unit_of_measure_id			Long Integer (4), 
	local_trait_name			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_treatment;
CREATE TABLE div_treatment
 (
	div_treatment_id			Long Integer (4), 
	div_treatment_uom_id			Long Integer (4), 
	div_obs_unit_id			Long Integer (4), 
	value			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_treatment_uom;
CREATE TABLE div_treatment_uom
 (
	div_treatment_uom_id			Long Integer (4), 
	qtl_treatment_ontology_id			Long Integer (4), 
	div_unit_of_measure_id			Long Integer (4)

);
-- CREATE ANY INDEXES ...

DROP TABLE div_unit_of_measure;
CREATE TABLE div_unit_of_measure
 (
	div_unit_of_measure_id			Long Integer (4), 
	unit_type			Text (50)

);
-- CREATE ANY INDEXES ...

DROP TABLE qtl_trait_ontology;
CREATE TABLE qtl_trait_ontology
 (
	qtl_trait_ontology_id			Long Integer (4)

);
-- CREATE ANY INDEXES ...

DROP TABLE qtl_treatment_ontology;
CREATE TABLE qtl_treatment_ontology
 (
	qtl_treatment_ontology_id			Long Integer (4)

);
-- CREATE ANY INDEXES ...



-- CREATE ANY Relationships ...
