CREATE TABLE users(
   id int not null auto_increment primary key,
   userName varchar(255),
   firstName varchar(255),
   lastName varchar(255),
   createdAt timestamp default current_timestamp
);

CREATE TABLE posts (
  id integer NOT NULL,
  title character varying(255) NOT NULL,
  blurb character varying(255),
  body text NOT NULL,
  published boolean,
  created_at date,
  updated_at date,
  CONSTRAINT posts_pkey PRIMARY KEY (id)
);

CREATE TABLE comments (
  id integer NOT NULL,
  post_id integer NOT NULL,
  comment text NOT NULL,
  created_at date,
  CONSTRAINT comments_pkey PRIMARY KEY (id)
);

CREATE INDEX comments_post_id ON comments(post_id)

