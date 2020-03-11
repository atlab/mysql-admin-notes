
Fixing Startup Errors
---------------------

This section outlines some issues related to server start and mitigations.

Broken Transaction Buffers
~~~~~~~~~~~~~~~~~~~~~~~~~~

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
~~~~~~~~~~~~~~~~~~~~~~

In some cases, corrupt transaction log buffers can result in secondary
crashes in the background purge threads. Setting `innodb_purge_threads=1` may reduce the likelyhood of this occurrence and help the server to start.

Manual Replication Control
~~~~~~~~~~~~~~~~~~~~~~~~~~

Normally, MySQL replication will start automatically on configured slaves.
In some cases, such as when slave errors are present, this may not be
desired.  To start the server without starting replication automaticlaly,
the variable 'skip-slave-start' can be set in my.cnf. This will keep the
last known replica log positions, but requires an explicit 'start slave'
command to restart replication after server restart.

