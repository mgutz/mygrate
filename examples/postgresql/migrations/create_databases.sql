drop database if exists db_dev;
drop user if exists user_dev;
drop database if exists db_test;
drop user if exists user_test;

create user user_dev password 'dev';
create database db_dev owner user_dev;
alter schema public OWNER TO user_dev;

create user user_test password 'test';
create database db_test owner user_test;
alter schema public OWNER TO user_test;
