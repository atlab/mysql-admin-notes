
Reviewing Tables / Foreign Keys
-------------------------------

Listing Schemas/Tables
~~~~~~~~~~~~~~~~~~~~~~

To list schemas / tables::

    mysql> select distinct(SCHEMA_NAME) from information_schema.schemata;
    mysql> select table_catalog, table_schema, table_name from tables 
           order by table_schema asc;

Determining Schema/Table Foreign Keys
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Determining the foreign keys to a table can be useful for information or
for administrative purposes, such as table removal/reload/cleanup, etc.

The MySQL `information_schema.referential_constraints` can be queried
to determine this information. Generically, to understand the contents of
this table, the constraint `CONSTRAINT_NAME` in `CONSTRAINT_SCHEMA.TABLE_NAME`
refers to the table `REFERENCED_TABLE_NAME` in the `UNIQUE_CONSTRAINT_SCHEMA`.

To list the forward dependencies of the table `schema.table`::

    mysql> SELECT CONSTRAINT_NAME, TABLE_NAME, REFERENCED_TABLE_NAME
           FROM information_schema.REFERENTIAL_CONSTRAINTS
           WHERE CONSTRAINT_SCHEMA = '<schema>'
           AND TABLE_NAME = '<table>';

To list the forward dependency tables of the whole schema `schema`::

    mysql> SELECT CONSTRAINT_SCHEMA, TABLE_NAME, UNIQUE_CONSTRAINT_SCHEMA,
	   REFERENCED_TABLE_NAME 
           FROM information_schema.REFERENTIAL_CONSTRAINTS 
           where constraint_schema='map_experiment';
  

To list the forward dependency schemas of the whole schema `schema`::

    mysql> SELECT distinct(UNIQUE_CONSTRAINT_SCHEMA)
           FROM information_schema.REFERENTIAL_CONSTRAINTS 
           where constraint_schema='schema';

see also: https://github.com/ixcat/djwip/ixcat/depstick dependency listing tool

