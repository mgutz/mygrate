# mygrate

Database migrations for MySQL and PostgreSQL database.

This utility uses SQL files for migrations that, if need be, can be run
by `mysql` or `psql` command line utilities. It does not try to be cute.


## Installation

    npm install -g mygrate

Depending on your database, you will need to install either

    npm install mysql

    npm install pg


## Running

To create `migrations` directory and `config.js` sample which must be
edited for your database.

    mygrate init

To create a migration script.

    mygrate gen add-tables

That command creates `migration/TIMESTAMP-add-tables/{down,up}.sql`. Edit
these scripts as needed.


To run migrations, do any of the following

    mygrate up                           # migrate all scripts
    mygrate down                         # down 1 migration
    mygrate down 2                       # down 2 migrations
    mygrate down all                     # down all migrations
    mygrate down TIMESTAMP-some-script   # down to migration before this one

To view migrations applied to the database

    mygrate

To target specific environments, `development` is default

    NODE_ENV=test mygrate up

