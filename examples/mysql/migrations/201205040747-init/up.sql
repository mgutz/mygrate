CREATE TABLE users(
   id int not null auto_increment primary key,
   userName varchar(255),
   firstName varchar(255),
   lastName varchar(255),
   createdAt datetime
);

CREATE TABLE posts (
  id integer NOT NULL,
  title character varying(255) NOT NULL,
  blurb character varying(255),
  body text NOT NULL,
  published boolean,
  created_at datetime,
  updated_at datetime,
  CONSTRAINT posts_pkey PRIMARY KEY (id)
);

CREATE TABLE comments (
  id integer NOT NULL,
  post_id integer NOT NULL,
  comment text NOT NULL,
  created_at datetime,
  CONSTRAINT comments_pkey PRIMARY KEY (id)
);

CREATE INDEX comments_post_id ON comments(post_id)

