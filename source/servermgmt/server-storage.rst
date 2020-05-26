
Managing Database Storage
-------------------------

Determining Disk Usage
~~~~~~~~~~~~~~~~~~~~~~

For per-column usage::

    mysql> SELECT sum(char_length($your_column))/1024/1024 FROM $your_table

For per table usage::

    mysql> select
               table_schema,
               table_name,
               ((data_length+index_length)/(1024*1024)) as mb,
               ((data_free)/(1024*1024)) as usage_gc
           from
               information_schema.tables
           order by table_schema;

For per schema usage::

    mysql> select
            table_schema,
            SUM((data_length+index_length)/(1024*1024)) as usage_mb,
            SUM((data_free)/(1024*1024)) as usage_gc
    from
            information_schema.tables
    group by table_schema
    order by usage_mb;

For whole-database usage::

    mysql> select 
    SUM((data_length+index_length)/(1024*1024)) as mb,
    SUM((data_free)/(1024*1024)) as gc
    from information_schema.tables;

Binary log size::

    -- todo: via information schema + summation
    mysql> show binary logs;

InnoDB tmp/undo space::

    mysql> select file_name, ((total_extents*extent_size)/1024/1024) as mb 
    from information_schema.files 
    where file_name like '%ibtmp%' or file_name like '%ibdata%';

Note: ibdata1 will always exist, and is used for undo space, and the only
way to reclaim (as of 5.7) is to fully rebuild the database. See also:

  https://www.percona.com/blog/2014/08/21/the-mysql-ibdata1-disk-space-issue-and-big-tables-part-1/
  https://bugs.mysql.com/bug.php?id=1341

MySQL 8 incorporates some features for moving undo space out of the innodb
system tablesspace (ibdata1), and adding/removing these undo buffers at runtime::

  See also: https://dev.mysql.com/doc/refman/8.0/en/innodb-undo-tablespaces.html

Outside of MySQL, disk space can be determined using the `du` command::

    # watch du -sk dbname/{table.*,#*}

Determining number of records in a Table
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To determine the number of rows, etc in a table, the information schema can
also be used::

    mysql> select table_schema,table_name,table_rows,data_length,
    index_length,max_data_length,data_free
    from tables where table_schema='mydb' and table_name='mytable';

Optimizing Tables
~~~~~~~~~~~~~~~~~

Space is not removed from InnoDB tables after record deletion, instead,
the corresponding 'slots' in the table are marked as empty and reused for
future records. When there are no free 'slots', the table is expanded.
Additionally, tables can become fragmented over time as records are removed,
creating holes, and new records are added back into these holes, the table
is grown, etc.

To rebuild a table, the `optimize table` command can be used::

    mysql> optimize table databasename.tablename;

This command creates a completely new table file, copies in existing records,
and then replaces the previous table with the newly created 'compact' one,
resulting in a 'clean' table which does not have fragmentation / empty 'slots'.

Since the mechanism uses a 'copy and replace' strategy, this operation
requires additional disk space up to the size of the number of 'real'
records in the table and so in the case of large tables should be performed
carefully to ensure that the server has sufficient free space.

see also:

  - disabling/reenabling indexes for faster/better optmization, etc
    https://www.percona.com/blog/2010/12/09/mysql-optimize-tables-innodb-stop/


Managing Temporary Tables
~~~~~~~~~~~~~~~~~~~~~~~~~

Temporary tables are built on disk to support joins across large tables.
These jobs will have the status `Converting HEAP to MyISAM` in the MySQL
processlist when they ocurr, and temporary files will be created in MySQL's
tmpdir.

Several variables relate to this setting. These should be tuned as large
as possible to support the expected number of concurrent in-memory joins
which will occur on the system to allow these jobs to run in memory and
therefore complete more quickly.

The variables are:

  - max_heap_table_size
  - tmp_table_size
  - join_buffer_size
  - max_join_size

See also:

  - https://forums.mysql.com/read.php?21,626664,626739#msg-626739
  - https://www.percona.com/blog/2010/07/05/how-is-join_buffer_size-allocated/


