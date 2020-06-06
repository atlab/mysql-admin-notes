
Individual Table Restore from Innobackup Backups using Replica Snapshots
------------------------------------------------------------------------

The procedure is very low level and can be error prone and so should be
used as as an 'emergency' / 'last resort' style of recovery option.

This procedure can be used to quickly load a subset of a full
innobackup backup without restoring the full database, which might
be time or storage prohibitive. It can be useful in the case of accidental
user data deletes, or other similar situations where only some portions
of the backup data are required.

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

From here, the exported data can then be reloaded into the real database,
and the temporary replica can be destroyed. 

.. see also: https://dev.mysql.com/doc/refman/5.6/en/innodb-troubleshooting-datadict.html

Individual Table Restore from Incremental Innobackup Backups
------------------------------------------------------------

This procedure is extremely low level and not well tested, and should be
used as a last resort and only with careful validation of data recovered.

In some cases, a partial data restore may be desired where the only copy
of the data is in an incremental backup set, for example when the data
did not exist at the time of the last full backup, or has been modified
since the last full innobackup backup.

Innobackup's incremental backup mode stores incremental changes in a
binary format based on the data available in previous runs within that
backup set (e.g. baseline full backup + previous incrementals against that 
baseline). As a result, the incremental backup data files only contain
the needed changes, which allows the files to be compact when compared
to the whole table, but also means that the files are not directly readable
as whole tables would be. The steps outlined here use special tools which
are aware of the binary incremental format to decode the incremental backup
data and extract the related records into a format usable by other mysql
tools.

Steps are as follows:

  1) Get SQL of table create (`show create table db.table;`) and save to a file

  2) Use https://github.com/twindb/undrop-for-innodb on the backup .delta to
     generate records::

       # ./c_parser -6 -f /backup/incremental-1/dbname/tablename.ibd.delta
       -t /tmp/tablename.schema.sql > /tmp/tablename.data.sql.recovered

     this program will generate a `load data infile` statement which should
     then be run against the generated file.

  3) Carefully investigate and load the extracted data.

Recreating empty Tablespaces
----------------------------

To completely recreate a table exactly without a schema on hand::

    mysql> show create table foo;
    mysql> drop table foo;
    mysql> <run create statement from 1st step>;

This can be used to recreate a corrupted table in empty state which can
subsequently be reloaded with appropriate data from a backup.

