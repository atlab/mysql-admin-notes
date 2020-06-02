
Replication Checksumming
------------------------

This section outlines replica checksumming using `pt-table-checksum`.

Unfortunately mysql statement based replication does not fully
replicate all statements safely (for example things relying on NOW()
execute using server time). To ensure integrity of replicas, checksums
should be run to compare master/slave values. This section outlines
notes using pt-table-checksum to work with replica checksums.

Running a Replica Checksum
--------------------------

The pt-table-checksum tool from percona-toolkit is used to perform
the database checksum against database masters. This tool will
create a 'percona.checksums' schema used to store checkusm status,
and do a byte-by-byte comparison of data between all instances of
the replica. The tool has many options to run against sets of schemas
and tables, and also to determine the type of check run (fresh check,
continue existing check, etc). An example invocation to perform checksums
on all tables not beginning with '__' is as follows::

  # pt-table-checksum --user root --password password \
    --socket /var/run/mysqld/mysqld.sock \
    --nocheck-plan --no-check-binlog-format --chunk-time=300 \
    --function fnv1a_64 --truncate-replicate-table --ignore-tables-regex ^__

See the pt-table-checksum(1) manual page for more details. Preliminary
scripting for the table checksums is available in the 'dbms' toolkit.

One thing to note is that the checksum tool will ensure that all replicas
are within a reasonable delay threshod from each other - this means that 
in the case of delayed replication, the delayed replica should be stopped,
or should be caught up to real-time replication before running a checksum
job, since a delayed replica will trigger this delay threshold test.

Determining Checksum Progress
~~~~~~~~~~~~~~~~~~~~~~~~~~~~-

Sometimes, it may be usesful to check on the checksum operation as it is 
running on a given table and estimate how long it might take to complete.
This section explains a method to do this.

First, determine number of rows in the table::

    mysql> select table_schema,table_name,table_rows,data_length,index_length,max_data_length,data_free from tables where table_schema='stimulation' and table_name='_stim_trial_events';

Then, check checksum progress::

    mysql> select * from information_schema.processlist where command != 'Sleep' 
and db='stimulation';

    mysql> select * from percona.checksums where db='stimulation';

Time the query, divide nrows by querytime to get the projected time.

Reviewing Checksum Status
~~~~~~~~~~~~~~~~~~~~~~~~~

TODO: document how to view the checksum report and query the checksum table.

Repairing Errors discovered in database checksums
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

TODO: document arguments to pt-table-checksum to generate repair SQL
... see also dbms code.

Tuning the `pt-table-checksum` runs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The checksum functions provided out of the box in MySQL are not ideal for
performing bulk data checksums. Either they are too weak to provide a
reasonable level of confidence (e.g. `CRC32`), or are so cryptographically
strong that they are computationally expensive (e.g. `MD5`). To work around
these limitations, and provide a faster means to compute a reasonable checksum
result, percona has released specific UDFs (User Defined Functions) which
can be installed into the MySQL Server to facillitate checksumming.

For installations of 'percona server for mysql', these plugins are available
by default as part of the database installation, otherwise, they must
be compiled and copied to the mysql plugin directory. Ubuntu steps::

    # apt install libmysqlclient-dev # for headers
    # cd percona-server-5.6.40-84.0/plugin/percona-udf
    # make build && make install-lib && make install-fn

Once the binary plugins are installed in the proper location, they must
be installed into the server as follows::

    mysql> CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so';
    mysql> CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so';
    mysql> CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so';

To test the functions::

    mysql> select fnv_64("hello"),fnv1a_64("hello"),murmur_hash("hello");
    +---------------------+----------------------+----------------------+
    | fnv_64("hello")     | fnv1a_64("hello")    | murmur_hash("hello") |
    +---------------------+----------------------+----------------------+
    | 5062650224559373796 | -6615550055289275125 |  5504495257757250616 |
    +---------------------+----------------------+----------------------+

More information about these functions are available from:

  https://www.percona.com/doc/percona-server/LATEST/management/udf_percona_toolkit.html

Also note: the murmur hash plugin in mysql has reported some issues:

  https://jira.percona.com/browse/PT-1420
 
