.. -*- mode: rst -*-

=================
MySQL Admin Notes
=================

Master-Slave Replication
========================

Generic notes for setting up master/slave replication, taken from test session
using ubuntu 16.04 virtual machines.

Prepare Master for Replication
------------------------------
.. todo: fill in notes

# 1
service mysql start
innobackupex /vagrant/bkup
innobackupex --apply-log /vagrant/bkup/2018-02-20_19-26-46/

# grep bind-address /etc/mysql/mariadb.conf.d/50-server.cnf
bind-address		= 0.0.0.0

grant all PRIVILEGES on *.* to 'root'@'%' 
identified by 'mysql' with grant option;
ufw allow 3306;

# 1
mysql -u root
GRANT REPLICATION SLAVE ON *.*  TO 'replication'@'%' 
IDENTIFIED BY 'replication';
GRANT REPLICATION SLAVE ON *.*  TO 'replication'@'%' 
IDENTIFIED BY 'replication';
-- better: (need process for pt-table-checksum)
GRANT SELECT, PROCESS, SUPER, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'test_user'@'%' IDENTIFIED BY PASSWORD 'replication';
flush privileges;

Prepare Slave for Replication
-----------------------------
.. todo: fill in notes

# 2 
mysql
grant all PRIVILEGES on *.* to 'root'@'%' 
identified by 'mysql' with grant option;

# grep bind-address /etc/mysql/mariadb.conf.d/50-server.cnf
bind-address		= 0.0.0.0

ufw allow 3306;
service mysql stop
rsync -avHS --delete /vagrant/bkup/2018-02-20_19-26-46/ /var/lib/mysql/
chown -R mysql:mysql /var/lib/mysql/
vi /etc/mysql/mariadb.conf.d/50-server.cnf
# server id; enable binlogs, etc

Enable Replication on Slave
---------------------------
.. todo: fill in notes

# 2
binlog=`awk '{print $1}' /var/lib/mysql/xtrabackup_binlog_info`
binpos=`awk '{print $2}' /var/lib/mysql/xtrabackup_binlog_info`
cat |mysql -u root <<EOF
CHANGE MASTER TO
MASTER_HOST='172.28.128.11',
MASTER_USER='replication',
MASTER_PASSWORD='replication',
MASTER_LOG_FILE='$binlog',
MASTER_LOG_POS=$binpos;
EOF
start slave;

# crash recovery
innodb recovery mode
find txn if corrupt
todo: txn 'sync_binlog=1' ?
# to inspect binlogs:
mysqlbinlog –-base64-output=decode-rows –-verbose -–start-position=82000301 mysql-bin.043343

Managing Replication Status
---------------------------
.. todo: fill in notes

# statii
SELECT variable_value 
FROM information_schema.global_status 
WHERE variable_name='SLAVE_RUNNING';

SHOW SLAVE STATUS; --- lots of stuff

-- flush tables with write lock to get consistent value;
show master status; -- current binfile / position

stop slave;
reset slave all;

# 5.7+ performance schema has replication tables
https://dev.mysql.com/doc/refman/5.7/en/performance-schema-replication-tables.htpml

Managing Replication Logs
-------------------------

Replication logs are typically called `mysql-bin.NNN` and are stored in
the mysql data directory. These files log changes to the database and
are retained for a configurable period of time. When slaves are enabled,
they read through the replication logs and apply changes to the local data,
and follow these logs continually once any backlog has been replayed.

The retention window dictates how far behind a slave database can be brought
in sync with the master, and similarly, since a new slave is based on a
database backup, how old database backups are valid for bringing replicas
online. 

In the event of too much 'churn' on the database, the amount of space
taken up by replication logs may exceed desired usage. To reduce this space,
the amount of replication information stored can be reduced. This action
will correspondingly shorten the time window for which replicas can be brought
online from a backup.

Current logfiles required by executing slaves can be determined via the
output of the `SHOW SLAVE STATUS\G;` command, specifically the values
of the `Master_Log_File` and `Relay_Master_Log_File`. The `Master_Log_File`
shows the current logfile being written to on the master, and the
variable `Relay_Master_Log_File` shows the current logfile being read by
the replica. At minimum, to maintain the current replication, logs should
be kept from the lowest `Relay_Master_Log_File` onward.

Cleanup / managment of these logs consists of two main actions:

  1) Purging of existing replication logs
  2) Altering log retention settings.

Cleanup of Replication Logs
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Cleanup can be performed as follows::

    mysql> PURGE BINARY LOGS TO 'binlogname';
    mysql> PURGE BINARY LOGS BEFORE 'datetimestamp';

more specifically::

    mysql> PURGE BINARY LOGS TO `mysql-bin.000223`;
  
will erase all binary logs before mysql-bin.000223, and::

    mysql> PURGE BINARY LOGS BEFORE DATE(NOW() - INTERVAL 3 DAY) + INTERVAL 0 SECOND;  
  
will erase all binary logs before midnight 3 days ago.

Replication Log Retention
~~~~~~~~~~~~~~~~~~~~~~~~~

The automatic retention period is set via the variable `expire_logs_days`,
and can be set at runtime as follows::

    mysql> SET GLOBAL expire_logs_days = 3;

and via the `my.cnf` configuration file as follows::

    [mysqld]
    expire_logs_days=3

see also: https://dba.stackexchange.com/questions/41050/is-it-safe-to-delete-mysql-bin-files

Managing Database Storage
=========================

Determining Disk Usage
----------------------

For per-column usage::

    mysql> SELECT sum(char_length($your_column))/1024/1024 FROM $your_table

For per table usage::

    mysql> select
               table_schema,
               table_name,
               ((data_length+index_length)/(1024*1024)) as mb
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
----------------------------------------

To determine the number of rows, etc in a table, the information schema can
also be used::

    mysql> select table_schema,table_name,table_rows,data_length,
    index_length,max_data_length,data_free
    from tables where table_schema='mydb' and table_name='mytable';

Optimizing Tables
-----------------

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
-------------------------

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


MySQL Server Timeout Values
===========================


    wait_timeout: inactive client timeout
    interactive_timeout: inactive timeout if 'CLIENT_INTERACTIVE' option set
    net_read_timeout: timeout for client->server data xmit/recv
    net_write_timeout: timeout for server->client data xmit/recv

    int(conn.query("show variables like 'net_read_timeout'").fetchall()[0][1])  # 60
    conn.query("set session net_read_timeout=90").fetchall()  # ()

    int(conn.query("show variables like 'net_write_timeout'").fetchall()[0][1])
    conn.query("set session net_read_timeout=90").fetchall()

.. see also: https://blog.pythian.com/connection-timeout-parameters-mysql/

Replication Checksumming
========================

Replica Checksumming using `pt-table-checksum`
----------------------------------------------

TODO: document running pt-table-checksum to checksum databases

Investigating the Checksum Table
--------------------------------

==== percona checsumming / working with

-- nrowsish
select table_schema,table_name,table_rows,data_length,index_length,max_data_length,data_free from tables where table_schema='stimulation' and table_name='_stim_trial_events';

-- checksum progress
select * from information_schema.processlist where command != 'Sleep' 
and db='stimulation';

--
select * from percona.checksums where db='stimulation';

time query; divide nrows by querytime, -> projected time

Repairing Errors discovered in database checksums
-------------------------------------------------

TODO: document arguments to pt-table-checksum to generate repair SQL

Tuning the `pt-table-checksum` runs
-----------------------------------


checksum stuff - (todo: expand notes)
defaults can result in slow queries and therefore checksums on some tables
due to over-granularity of chunks
disabling query plan checking might facillitate this working,
but could result in spurious load
instead setting only some columns (--chunk-index-columns) can result in
duplicated chunks (keys are not unique), which breaks checks 
also, --chunk-size-limit likely needs a higher value for small record tables
  (which again could impact performance on big ones)
todo: check query plan disaled method for stimluation._stim_trial_events.
ostensibly once innodb update times stored, could do a 'dumber' check method. 


Percona Toolkit UDFs for pt-table-checksum
------------------------------------------

The checksum functions provided out of the box in MySQL are not ideal for
performing bulk data checksums. Either they are too weak to provide a
reasonable level of confidence (e.g. `CRC32`), or are so cryptographically
strong that they are computationally expensive (e.g. `MD5`). To work around
these limitations, and provide a faster means to compute a reasonable checksum
result, percona has released specific UDFs (User Defined Functions) which
can be installed into the MySQL Server to facillitate checksumming.

For installations of 'percona server for mysql', these plugins are available
by default as part of the database installation, otherwise, they must
be compiled and copied to the mysql plugin directory.

Once the binary plugins are installed in the proper location, they must
be installed into the server as follows::

    mysql> CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so';
    mysql> CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so';
    mysql> CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so';

More information about these functions are available from:

  https://www.percona.com/doc/percona-server/LATEST/management/udf_percona_toolkit.html

Also note: the murmur hash plugin in mysql has reported some issues:

  https://jira.percona.com/browse/PT-1420

LVM Database Snapshots
----------------------

To create online snapshots of a replica using LVM snapshots, the following
steps can be taken (requires the database volume be stored on an LVM partition)

1) Stop replication and database write activity.

   To ensure that the LVM snapshot is created from a valid on-disk state,
   database write activity should be stopped prior to taking the snapshot.
   This should be done from a mysql session as follows::

     mysql> stop replication;
     mysql> flush tables with read lock;

   The MySQL session should be kept open for the subsequent step which
   creates the actual LVM snapshot.

2) Create LVM Snapshot

   In a separate terminal, create the LVM snapshot as follows::


     # lvcreate -L4T -s -n dblv1-snap /dev/dbvg1/dblv1

   This creates a snapshot with 4TB of delta/working space from dblv1
   called dblv1-snap. The delta space is used to track changes from
   the underlying LVM volume; once the two differ by more than this space
   the snapshot becomes invalid.

3) Reenable database write activity and replication.

   To reenable write activity and replication, the steps performed in step
   #1 should be reversed as follows::

     mysql> unlock tables;
     mysql> start slave;

From here, the snapshot volume can be mounted and used for backups or
running a secondary MySQL instance for debugging / testing, etc.


===== building new slave copy from slave backup

use '--slave-info' xtrabackup option - and values in xtrabackup_slave_info 
file rather than xtrabackup_binlog_info file. Example:

  # cat xtrabackup_slave_info 
  CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.048008', MASTER_LOG_POS=9014377

see also: https://www.percona.com/doc/percona-xtrabackup/2.1/howtos/setting_up_replication.html#adding-more-slaves-to-the-master

Delayed Replication
====================

CHANGE MASTER TO MASTER_DELAY = N;

Low-Level Table Managment
=========================

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

Reviewing Tables / Foreign Keys
===============================

Listing Schemas/Tables
----------------------

To list schemas / tables::

    mysql> select distinct(SCHEMA_NAME) from information_schema.schemata;
    mysql> select table_catalog, table_schema, table_name from tables 
           order by table_schema asc;

Determining Schema/Table Foreign Keys
-------------------------------------

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

.. see also: github/ixcat/djwip/ixcat/depstick schema dependency listing tool


Fixing Replication Errors
=========================

While master/slave replication is generally very stable, in certain conditions
a replication error can occur. MySQL Replication has different low-level
replication mechanisms, the simplest of which is 'statement based replication'.
This mechanism logs individual SQL statements to a replication log, which is
then replayed on the slave to keep the two copies in sync. In almost all cases,
statements execute correctly on the slave, however, since queries are serialized
and some queries may be non-deterministic (e.g. rely on other data values
to compute their results), in some rare cases, an SQL statement will fail on
the replica, breaking the replication. In these cases, manual intervention
is required to either manually sync the offending replica data, some replication
are skipped, or some combination of both.

Inspecting the Replication Error
--------------------------------

Errors will be visible on impacted replicas using the `show slave status`
command. For example::

    mysql> show slave status;
    ...
    Error 'Cannot add or update a child row: a foreign key constraint fails ...

Manual Data Sync Fix
--------------------

Record details will be visible in the error message, which can then be used
to inspect table data on the master and the replica and fix the error::

    mysql(slave)> select ... ;
    mysql(master)> select ... ;
    mysql(slave)> insert into ... values ((...));

From here, the replication can be resumed with `start slave;`. While always
a good idea to periodically checksum tables in general, and especially after
manual intervention on replication is required, if successful this method
does ensure that the full replication log is still replayed on the client
and so is one of the safest replication repairs that can be performed.

Skipping Replication Events
---------------------------

In the event of more complex failures, the replica can be configured
to skip some number of initial statements from the master::

  mysql(slave)> SET GLOBAL sql_slave_skip_counter = 1;

From here, the `start slave;` command can be issued and replication can
resume. It should be noted that in this case, there is a potential that
the missing statement introduced some inconsistent change on the replica;
impacted tables should subsequently be compared using a checksum test
and updated accordingly to fix the impacted tables.

Skipping Specific Replication Errors
------------------------------------

In some cases, a specific section of replication logs generates too many
errors for the `sql_slave_skip_counter` method to work. In this case,
the replica can be restarted ignoring certain replication errors in order
to proceed through the problematic 'chunk' of the replication log. To do
this, first, extract the error code from the `show slave status` error,
and then adjust the slave's `my.cnf` accordingly. For example, to
skip duplicate entry errors, the following adjustment can be made::

  $ grep 'slave-skip-errors' /etc/my.cnf
  slave-skip-errors = 1062  -- duplicate entries

Once restarted, the replica should proceed past the error statements
and continue on. Once past the 'problem area' in the replication logs,
the replica can be stopped, the setting removed, and the replica restarted.

Due to the fact that errors are actually skipped while this change is active,
it is crucially important that a master/slave checksum test is performed
and any discrepancies are manually fixed on the replica.

Fixing Startup Errors
=====================

This section outlines some issues related to server start and mitigations.

Broken Transaction Buffers
--------------------------

In some rare crashes, transaction log buffers may become broken and cause
a crash during startup. This usually happens when inappropriate sync
level is configured (TODO: fsync method etc) and the system crashes. To
attempt recovery, the server variable `innodb_force_recovery` can be
used to skip certain kinds of errros. Settings should be set to 1 and
incrementally increased in the presence of failures, after consulting
documentation about the impact of the change. A setting of 1 is maximally
safe; Settings above 3 *will* cause some level data corruption. See the
documentation for more details.

Crashing Purge Threads
----------------------

In some cases, corrupt transaction log buffers can result in secondary
crashes in the background purge threads. Setting `innodb_purge_threads=1` may reduce the likelyhood of this occurrence and help the server to start.

Manual Replication Control
--------------------------

Normally, MySQL replication will start automatically on configured slaves.
In some cases, such as when slave errors are present, this may not be
desired.  To start the server without starting replication automaticlaly,
the variable 'skip-slave-start' can be set in my.cnf. This will keep the
last known replica log positions, but requires an explicit 'start slave'
command to restart replication after server restart.

Transaction Lock Debugging
==========================

==== debugging transaction locks

-- via: http://abiasforaction.net/debugging-transactional-and-locking-issues-in-mysql/

SELECT 
    tw_ps.DB waiting_trx_db,
    r.trx_id waiting_trx_id,
    r.trx_mysql_thread_id waiting_thread,
    r.trx_query waiting_query,
    bt_ps.DB blocking_trx_db,
    b.trx_id blocking_trx_id,
    b.trx_mysql_thread_id blocking_thread,
    b.trx_query blocking_query
FROM
    information_schema.innodb_lock_waits w
        INNER JOIN
    information_schema.innodb_trx b ON b.trx_id = w.blocking_trx_id
        INNER JOIN
    information_schema.innodb_trx r ON r.trx_id = w.requesting_trx_id
		INNER JOIN information_schema.processlist tw_ps ON tw_ps.ID = r.trx_id
        		INNER JOIN information_schema.processlist bt_ps ON bt_ps.ID = b.trx_id
WHERE  r.trx_id in (Select ID FROM information_schema.processlist where DB='YOUR_DB_NAME') ;

More Lock Debugging
===================

Via: 

  - https://stackoverflow.com/questions/13148630/
    how-do-i-find-which-transaction-is-causing-a-waiting-for-table-metadata-lock-s

Useful Queries
  
  - To check about all the innodb locks transactions are waiting for::
  
      USE INFORMATION_SCHEMA;
      SELECT * FROM INNODB_LOCK_WAITS;
  
  - A list of innodb blocking transactions::
  
      SELECT * 
      FROM INNODB_LOCKS 
      WHERE LOCK_TRX_ID IN (SELECT BLOCKING_TRX_ID FROM INNODB_LOCK_WAITS);
  
      OR
  
      SELECT INNODB_LOCKS.* 
      FROM INNODB_LOCKS
      JOIN INNODB_LOCK_WAITS
      ON (INNODB_LOCKS.LOCK_TRX_ID = INNODB_LOCK_WAITS.BLOCKING_TRX_ID);
  
  - A List of innodb locks on perticular table::
  
      SELECT * FROM INNODB_LOCKS 
      WHERE LOCK_TABLE = db_name.table_name;
  
  - A list of innodb transactions waiting for locks::
  
      SELECT TRX_ID, TRX_REQUESTED_LOCK_ID, TRX_MYSQL_THREAD_ID, TRX_QUERY
      FROM INNODB_TRX
      WHERE TRX_STATE = 'LOCK WAIT';
  
  - mysql 5.7 exposes metadata lock information through the
    performance_schema.metadata_locks table.

MySQL User/Account Managment
============================


Change Password
---------------

Passwords can be changed in MySQL as follows::

    mysql> set password for 'user'@'%' = password('text password');

another syntax is::

    mysql> UPDATE mysql.user SET Password=PASSWORD('text password') WHERE user=”username” AND Host=”hostname”;


Per-Flavor MySQL Notes
======================

MariaDB
-------

mariabackup
~~~~~~~~~~~

mariabackup (mariadb's xtrabackup fork)
https://mariadb.com/kb/en/library/mariadb-backup-overview/
apparently needed for mariadb ~10.1.26+ (and definately 10.3) instead
of the percona xtrabackup tool.

Example install/usage::

  # apt-get install mariadb-backup-10.3
  # mariabackup --user=root --password=maria --target-dir=/net/backup --backup
  # mariabackup --target-dir=/net/backup --prepare


Lock Wait Debugging in MySQL
============================

This section outlines the steps needed for investigating lock wait timeouts
using the MySQL performance schema.

More information on the `performance schema` is availble in the MySQL
reference documentation[#]_ .

.. [#] https://dev.mysql.com/doc/refman/5.6/en/performance-schema.html

.. todo: include/refile:
.. https://www.percona.com/doc/percona-server/LATEST/diagnostics/innodb_show_status.html
.. https://bugs.launchpad.net/percona-server/+bug/1657737

Configuration
-------------

The required settings to facilliate debugging lock wait timeouts are as follows:

  1) In MySQL Server Configuration (e.g. mysqld.cnf)::

       performance_schema=ON;
       innodb_print_lock_wait_timeout_info=ON;

  2) After Server Start::

       mysql> update performance_schema.setup_consumers
           -> set enabled="YES" where name="events_statements_history";
       mysql> update performance_schema.setup_consumers
           -> set enabled="YES" where name="events_statements_history_long";

     These can also be set via mysqld startup arguments, but unfortunately,
     not via mysqld.cnf. Since modifying startup arguments can be cumbersome,
     the runtime/mysql interface is discussed here. See reference documentation
     if startup argument method is preferred.

Relevant Performance Schema Tables
----------------------------------

As suggested in the `Configuration`_ section, lock debugging is facillitated
through the use of statement history tables in the MySQL performance schema.

The key tables and their functions are as follows:

============================== ============================================
Table                          Function
============================== ============================================
events_statements_current      Describes currently executing SQL statements
events_statements_history      Describes per-thread SQL statement history
events_statements_history_long Describes server-wide SQL statement history
============================== ============================================

Other tables related to executing queries are also available, and may provide
similar information.

The statement history tables outline adbove will keep an auto-sized number
of history records; this autosizing can be overridden if desired via the usual 
mechanism to manage server variables (`SET/SHOW GLOBAL`) for the following:

  - perfomance_schema_events_statements_history_size
  - perfomance_schema_events_statements_history_long_size

Looking up Lock Wait Timeout Information
----------------------------------------

To look up a lock wait timeout, perform the following steps:

  1) Fetch the lock wait timeout message from the mysql server log::

       # grep -A 10 'Lock wait timeout info:' /var/log/mysql/error.log

     *Note*: adjust `-A 10` as necessary to recover the full information
     about the timeout information as needed.

  2) Interpret the information from the lock timeout message.

     Lock wait messsages will appear as follows::

       2019-11-14T18:32:11.316770Z 37 [Note] InnoDB: Lock wait timeout info:
       Requested thread id: 37
       Requested trx id: 10388
       Requested query: DELETE FROM `test_locker`.`#feather` WHERE ((((`tar_id`=2))))
       Total blocking transactions count: 2
       Blocking transaction number: 1
       Blocking thread id: 36
       Blocking query id: 1136
       Blocking trx id: 10387
       Blocking transaction number: 2
       Blocking thread id: 35
       Blocking query id: 1125
       Blocking trx id: 10259
   
     As can be seen in the example, the time of the lock wait timouet along with
     information about the thread requesting the lock and threads blocking the
     request are available in the log message.

  3) Retrieve additional information about the blocking threads.

     The information recovered in #1 can be used to retrieve additional
     information about blocking threads by querying the performance schema.

     a) To determine the processes responsible for blocking the lock request::

          mysql> select processlist_id,processlist_user,processlist_host
              -> from performance_schema.threads
              -> where processlist_id in (36, 35);

     b) To determine the queries responsible for blocking the lock request
        in each of the blocking threads::

          mysql> select s.sql_text 
              -> from performance_schema.events_statements_history s 
              -> inner join performance_schema.threads t 
              -> on t.thread_id = s.thread_id 
              -> where t.processlist_id = 35
              -> union 
              -> select s.sql_text 
              -> from performance_schema.events_statements_current s 
              -> inner join performance_schema.threads t 
              -> on t.thread_id = s.thread_id 
              -> where t.processlist_id = 35;

        To note, this will not provide the directly responsible query for
        the blocking lock request, but instead will provide the available
        statement history related to the blocking thread. This information
        can then be cross-checked against the calling thread query to
        determine the reason behind the lock wait timeout.
