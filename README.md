# mygrate

Database migrations for MySQL, PostgreSQL and SQL Server database using plain
SQL files. The end goal is to have migration scripts that can be run by a DBA.

## Installation

    npm install -g mygrate

## Walkthrough

For a project without migrations, mygrate creates a `migrations`
directory and `migrations/config.js` example which MUST BE edited for your
database. Run one of the following commands

    mygrate init postgresql             # Postgresql
    mygrate init mssql                  # Sql Server
    mygrate init mysql                  # MySQL

Next step is to create the database in the config if it does not
already exist. Mygrate will prompt for root user and password. Run
one of the following

    mygrate createdb                    # creates development database
    mygrate createdb --me               # creates database using current user
    NODE_ENV=test mygrate createdb      # creates test database

To create a set of migration scripts, run the following command changing `add-tables`
to describe your migration

    mygrate new add-tables

That command creates `migration/TIMESTAMP-add-tables/{down,up}.sql`. Edit
`up.sql` which is run by `mygrate up` command. Edit `down.sql` which
is run by `mygrate down` command.

To run migrations, do any of the following

    mygrate up                           # migrate all scripts
    mygrate down                         # down 1 migration
    mygrate down 2                       # down 2 migrations
    mygrate down all                     # down all migrations
    mygrate down TIMESTAMP-some-script   # down to migration before this one
    mygrate last                         # down (if needed) then up last dir

To view migrations applied to the database

    mygrate

To target specific environments, `development` is default

    NODE_ENV=test mygrate up

## Stored Procedures

The postgres driver will register or updated store procedures
(user defined functions) for any file matching `./migrations/sprocs/*.sql`
on each migration. Mygrate is smart enough to only update the sproc if the
body has changed by comparing the hash value of the body. In this manner,
stored procedures can be versioned just like other source code.

A file can contain more than one stored procedure by using the special
marker `GO` on its own line. For example, this will register `f_fangames_join`
and `f_fangames_set_teams`.

```sql
/**
 *
 */
create function f_fangames_join(
    _bounty_id bigint
) as $$
DECLARE
BEGIN
END;
$$ language plpgsql;

GO

create function f_fangames_set_teams(
    _bounty_id bigint
) RETURNS void as $$
DECLARE
BEGIN
END;
$$ language plpgsql;
```

## Non-transactional Migrations

Postgres will complain if some statements occur inside a transaction.
Mygrate runs most migrations in a transaction.

## Compiling

    make compile
