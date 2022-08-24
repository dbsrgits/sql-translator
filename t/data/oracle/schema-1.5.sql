CREATE TABLE t_category (
  category_id number(11) NOT NULL,
  display_name varchar2(256) NOT NULL,
  description varchar2(4000) NOT NULL,
  added date DEFAULT CURRENT_TIMESTAMP NOT NULL,
  added_by varchar2(32) NOT NULL,
  modified date,
  modified_by varchar2(32),
  PRIMARY KEY (category_id),
  CONSTRAINT t_category_display_name UNIQUE (display_name)
);


CREATE SEQUENCE sq_t_message_message_id;

CREATE TABLE t_message (
  message_id number(11) NOT NULL,
  alert_id number(45) NOT NULL,
  from_address varchar2(256) NOT NULL,
  recipient nvarchar2(64) NOT NULL,
  subject_line varchar2(512) NOT NULL,
  body_text clob NOT NULL,
  body_html clob NOT NULL,
  short_body varchar2(160) NOT NULL,
  template_id number(11) NOT NULL,
  added date DEFAULT CURRENT_TIMESTAMP NOT NULL,
  added_by varchar2(32) NOT NULL,
  modified date,
  modified_by varchar2(32),
  PRIMARY KEY (message_id)
);


CREATE TABLE t_user (
  user_id varchar2(32) NOT NULL,
  name varchar2(256),
  last4_pid varchar2(4) NOT NULL,
  pidm number(11) NOT NULL,
  added date DEFAULT CURRENT_TIMESTAMP NOT NULL,
  added_by varchar2(32) NOT NULL,
  modified date,
  modified_by varchar2(32),
  mobile_phone varchar2(11),
  mobile_phone_source varchar2(64),
  reason_for_change varchar2(128),
  im_id varchar2(512),
  opt_in date,
  opt_in_confirm date,
  mobile_phone_2 varchar2(11),
  PRIMARY KEY (user_id),
  CONSTRAINT t_user_pidm UNIQUE (pidm)
);


CREATE SEQUENCE sq_t_population_group_group_;

CREATE TABLE t_population_group (
  group_id number(11) NOT NULL,
  group_name varchar2(256) NOT NULL,
  group_description varchar2(256) NOT NULL,
  group_role number(11),
  added date DEFAULT CURRENT_TIMESTAMP NOT NULL,
  added_by varchar2(32) NOT NULL,
  modified date,
  modified_by varchar2(32),
  group_type varchar2(256),
  group_sql clob NOT NULL,
  active number(1) NOT NULL,
  source varchar2(256) NOT NULL,
  private number(1) NOT NULL,
  fpm_bldg_no varchar2(11) NOT NULL,
  PRIMARY KEY (group_id)
);


CREATE SEQUENCE sq_t_role_role_id;

CREATE TABLE t_role (
  role_id number(11) NOT NULL,
  role_name varchar2(64) NOT NULL,
  role_desc varchar2(128) NOT NULL,
  PRIMARY KEY (role_id)
);


CREATE SEQUENCE sq_t_alert_alert_id;

CREATE TABLE t_alert (
  alert_id number(11) NOT NULL,
  category number(11) NOT NULL,
  title varchar2(64) NOT NULL,
  allow_email_opt_out number(1) NOT NULL,
  enabled number(1) NOT NULL,
  added date DEFAULT CURRENT_TIMESTAMP NOT NULL,
  added_by varchar2(32) NOT NULL,
  modified date,
  modified_by varchar2(32),
  PRIMARY KEY (alert_id)
);


CREATE TABLE t_user_groups (
  user_id varchar2(32) NOT NULL,
  group_id number(11) NOT NULL,
  PRIMARY KEY (user_id, group_id)
);


CREATE TABLE t_user_roles (
  user_id varchar2(32) NOT NULL,
  role_id number(11) NOT NULL,
  PRIMARY KEY (user_id, role_id)
);


CREATE TABLE t_category_defaults (
  category_id number(11) NOT NULL,
  user_id varchar2(32) NOT NULL,
  default_email number(1) NOT NULL,
  default_sms number(1) NOT NULL,
  default_push number(1) NOT NULL,
  default_im number(1) NOT NULL,
  modified date,
  modified_by varchar2(32),
  PRIMARY KEY (category_id, user_id)
);


CREATE TABLE t_alert_roles (
  alert_id number(11) NOT NULL,
  role_id number(11) NOT NULL,
  PRIMARY KEY (alert_id, role_id)
);

ALTER TABLE t_alert ADD CONSTRAINT t_alert_category_fk FOREIGN KEY (category) REFERENCES t_category (category_id);

ALTER TABLE t_user_groups ADD CONSTRAINT t_user_groups_group_id_fk FOREIGN KEY (group_id) REFERENCES t_population_group (group_id) ON DELETE CASCADE;

ALTER TABLE t_user_roles ADD CONSTRAINT t_user_roles_role_id_fk FOREIGN KEY (role_id) REFERENCES t_role (role_id) ON DELETE CASCADE;

ALTER TABLE t_category_defaults ADD CONSTRAINT t_category_defaults_category FOREIGN KEY (category_id) REFERENCES t_category (category_id);

ALTER TABLE t_category_defaults ADD CONSTRAINT t_category_defaults_user_id FOREIGN KEY (user_id) REFERENCES t_user (user_id);

ALTER TABLE t_alert_roles ADD CONSTRAINT t_alert_roles_alert_id_fk FOREIGN KEY (alert_id) REFERENCES t_alert (alert_id) ON DELETE CASCADE;

ALTER TABLE t_alert_roles ADD CONSTRAINT t_alert_roles_role_id_fk FOREIGN KEY (role_id) REFERENCES t_role (role_id);

ALTER TABLE t_population_group ADD CONSTRAINT t_population_group_group_role_fk FOREIGN KEY (group_role) REFERENCES t_role (role_id);

CREATE INDEX t_alert_idx_category on t_alert (category);

CREATE INDEX t_user_groups_idx_group_id on t_user_groups (group_id);

CREATE INDEX t_user_roles_idx_role_id on t_user_roles (role_id);

CREATE INDEX t_category_defaults_idx_cate on t_category_defaults (category_id);

CREATE INDEX t_category_defaults_idx_acce on t_category_defaults (user_id);

CREATE INDEX t_alert_roles_idx_alert_id on t_alert_roles (alert_id);

CREATE INDEX t_alert_roles_idx_role_id on t_alert_roles (role_id);

CREATE OR REPLACE TRIGGER ai_t_message_message_id
BEFORE INSERT ON t_message
FOR EACH ROW WHEN (
 new.message_id IS NULL OR new.message_id = 0
)
BEGIN
 SELECT sq_t_message_message_id.nextval
 INTO :new.message_id
 FROM dual;
END;
/

CREATE OR REPLACE TRIGGER ai_t_population_group_group_
BEFORE INSERT ON t_population_group
FOR EACH ROW WHEN (
 new.group_id IS NULL OR new.group_id = 0
)
BEGIN
 SELECT sq_t_population_group_group_.nextval
 INTO :new.group_id
 FROM dual;
END;
/

CREATE OR REPLACE TRIGGER ai_t_role_role_id
BEFORE INSERT ON t_role
FOR EACH ROW WHEN (
 new.role_id IS NULL OR new.role_id = 0
)
BEGIN
 SELECT sq_t_role_role_id.nextval
 INTO :new.role_id
 FROM dual;
END;
/

CREATE OR REPLACE TRIGGER ai_t_alert_alert_id
BEFORE INSERT ON t_alert
FOR EACH ROW WHEN (
 new.alert_id IS NULL OR new.alert_id = 0
)
BEGIN
 SELECT sq_t_alert_alert_id.nextval
 INTO :new.alert_id
 FROM dual;
END;
/