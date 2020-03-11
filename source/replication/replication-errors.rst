
Fixing Replication Errors
-------------------------

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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Errors will be visible on impacted replicas using the `show slave status`
command. For example::

    mysql> show slave status;
    ...
    Error 'Cannot add or update a child row: a foreign key constraint fails ...

Manual Data Sync Fix
~~~~~~~~~~~~~~~~~~~~

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
~~~~~~~~~~~~~~~~~~~~~~~~~~~

In the event of more complex failures, the replica can be configured
to skip some number of initial statements from the master::

  mysql(slave)> SET GLOBAL sql_slave_skip_counter = 1;

From here, the `start slave;` command can be issued and replication can
resume. It should be noted that in this case, there is a potential that
the missing statement introduced some inconsistent change on the replica;
impacted tables should subsequently be compared using a checksum test
and updated accordingly to fix the impacted tables.

Skipping Specific Replication Errors
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

Investigating Replication Logs
------------------------------

In some cases, you may wish to investigate replication logs on the server
to find the position of a problematic set of queries, etc. This can be done
using the `mysqlbinlog` tool in combination with `show master status` on
the master or `show slave status` on the slave. For example::

    # mysqlbinlog –-base64-output=decode-rows –-verbose -–start-position=82000301 mysql-bin.043343

would show the contents of the replication log 'mysql-bin.043343' starting
at position 82000301.

