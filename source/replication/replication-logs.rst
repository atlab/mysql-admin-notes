
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

