# Schema

Schema migrations for MySQL and PostgreSQL database.

This utility uses SQL file for migrations that, if need be, can be run
by `mysql` or `psql` command line utilities. It does not try to be cute.


## Installation

    npm install -g schema

To run migrations for MySQL

    npm install mysql

To run migrations for PostgreSQL

    npm install pg


## Running

To create `migrations` directory and `config.js` sample which must be
edited for your database.

    schema init

To create a migration script.

    schema gen add-tables

That command creates `migration/TIMESTAMP-add-tables/{down,up}.sql`. Edit
these scripts as needed.


To run migrations, do any of the following

    schema up                           # migrate all scripts
    schema down                         # down 1 migration
    schema down 2                       # down 2 migrations
    schema down all                     # down all migrations
    schema down TIMESTAMP-some-script   # down to migration before this one

To view migrations applied to the database

    schema

To target specific environments, `development` is default

    NODE_ENV=test schema up

