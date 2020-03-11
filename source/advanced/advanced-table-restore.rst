
Low-Level Restore of individual Tables via Backups/Replica Snapshots
--------------------------------------------------------------------

This procedure is very low level and can be error prone and so should be
used as as an 'emergency' / 'last resort' style of recovery option.

This method uses LVM snapshots of a live replica to allow quickly building
a temporary replica which is used to restore the table. Within the temporary
replica, the per-table `.ibd` datafile is disconnected from it's `.frm` schema
description, and a copy of the `.ibd` datafile is then 'reconnected' to
the live database to allow querying of the table.

Steps are as follows:

   - create a replica snapshot
   - mount *snapshot* volume under a separate mountpoint
   - start a new MySQL instance on the snapshot volume
   - stop slave on this replica
   - reset slave on this replica
   - if possible, describe table d.t;
   - ALTER TABLE db.table DISCARD TABLESPACE; -- this purges data only
   - copy .ibd file into place from backup w/correct permissions
   - ALTER TABLE sakila.actor IMPORT TABLESPACE; -- this 'reconnects' data file
   - the individually restored table should be queryable from here

To dump this table as CSV::

    mysql> select filld1,field2 into outfile '/tmp/table.csv'
    FIELDS TERMINATED BY ',' ENCLOSED BY '"' ESCAPED BY '"'
    lines terminated  by '\n' from db.tbl;

To dump the individual table as SQL::

    # mysqldump microns_ta3 soma > /tmp/soma.sql # with 'create table'
    # mysqldump -nt microns_ta3 soma > /tmp/soma.sql # without 'create table'

.. see also: https://dev.mysql.com/doc/refman/5.6/en/innodb-troubleshooting-datadict.html

Recreating empty Tablespaces
----------------------------

To completely recreate a table exactly without a schema on hand::

    mysql> show create table foo;
    mysql> drop table foo;
    mysql> <run create statement from 1st step>;

This can be used to recreate a corrupted table in empty state which can
subsequently be reloaded with appropriate data from a backup.

Individual Table restores from Partial Innobackup Backups
---------------------------------------------------------

This procedure is extremely low level and not well tested, and should be
used as a last resort and only with careful validation of data recovered.

Steps are as follows:

  1) Get SQL of table create (`show create table db.table;`) and save to a file

  2) Use https://github.com/twindb/undrop-for-innodb on the backup .delta to
     generate records::

       # ./c_parser -6 -f /backup/incremental-1/dbname/tablename.ibd.delta
       -t /tmp/tablename.schema.sql > /tmp/tablename.data.sql.recovered

     this program will generate a `load data infile` statement which should
     then be run against the generated file.

