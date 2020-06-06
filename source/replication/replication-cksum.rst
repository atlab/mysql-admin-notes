
Replication Checksumming
------------------------

This section outlines replica checksumming using `pt-table-checksum`.

Unfortunately mysql statement based replication does not fully
replicate all statements safely (for example things relying on NOW()
execute using server time on each replica), and in some cases,
manual intervention on replication is required. To ensure integrity
of replicas in the face of these events, checksums should be run
to compare master/slave values.  This section outlines notes using
pt-table-checksum to work with replica checksums.

Some limited support for scripted checksumming is available in the
dbms tool, the sections which follow describe the underlying
tools/techniques used as well as various topics such as data
reconcilliation process, checksum performance, etc., not covered
by the scripting.

Running a Replica Checksum
~~~~~~~~~~~~~~~~~~~~~~~~~~

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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Sometimes, it may be usesful to check on the checksum operation as it is 
running on a given table and estimate how long it might take to complete.
This section explains a method to do this.

First, determine number of rows in the table::

    mysql> select 
        table_schema,table_name,table_rows,data_length,index_length,
        max_data_length,data_free 
    from tables 
    where table_schema='stimulation' and table_name='_stim_trial_events';

Then, check checksum progress::

    mysql> select * from information_schema.processlist 
    where command != 'Sleep' and db='stimulation';

    mysql> select * from percona.checksums where db='stimulation';

Time the query, divide nrows by querytime to get the projected time.

Reviewing Checksum Results
~~~~~~~~~~~~~~~~~~~~~~~~~~

Once a checksum has been run, the pt-table-checksum tool can be used
to review the status of the checksummed data::

    # /usr/bin/pt-table-checksum \
                --ignore-tables-regex '^__' \
                --replicate-check-only
    Checking if all tables can be checksummed ...
    Starting checksum ...
    Differences on at-database2
    TABLE CHUNK CNT_DIFF CRC_DIFF CHUNK_INDEX LOWER_BOUNDARY UPPER_BOUNDARY
    mysql.db 1 2 1   
    mysql.engine_cost 1 0 1   
    mysql.proc 1 0 1   
    mysql.server_cost 1 0 1   
    mysql.tables_priv 1 0 1   
    mysql.user 1 0 1   

As can be seen from the above, the 'mysql.db' table contains 1 chunk with
differences, with the count of records differing by 2 (CNT_DIFF), and
the checksum mismatching in one record (CRC_DIFF).

Alternately, the percona.checksums table can be queried interactively::

    # mysql <<EOF
    SELECT db, tbl, SUM(this_cnt) AS total_rows, COUNT(*) AS chunks
    FROM percona.checksums
    WHERE (
       master_cnt <> this_cnt
       OR master_crc <> this_crc
       OR ISNULL(master_crc) <> ISNULL(this_crc))
    GROUP BY db, tbl;
    EOF

If this query returns no rows, there were no differences found.

Viewing/Repairing Checksum Errors
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If differences are found during a checksum run, manual intervention is
required to resolve the differences in the replicas. The pt-table-sync
tool can be used to determine the precise differences between the master
and the replicas, and also, if desired, to apply the changes to the replica.

The examples which follow will view/repair all detected changes. In practice
it might make more sense to work on some subset of the changes, for example
in a single database or table - pt-table-sync supports this mode of operation
as well, for details, see the pt-table-checksum documentation.

To view needed changes, run pt-table-sync with the `--print` argument::

    # pt-table-sync --print --replicate 'percona.checksums' localhost
    DELETE FROM `nsearch_v30_tiny_imagenet`.`~log` WHERE `timestamp`='20190721162837' LIMIT 1 /*percona-toolkit src_db:nsearch_v30_tiny_imagenet src_tbl:~log src_dsn:D=nsearch_v30_tiny_imagenet,S=/var/run/mysqld/mysqld1.sock,h=at-database1,p=...,t=~log,u=root dst_db:nsearch_v30_tiny_imagenet dst_tbl:~log dst_dsn:D=nsearch_v30_tiny_imagenet,S=/var/run/mysqld/mysqld1.sock,h=at-database2,p=...,t=~log,u=root lock:1 transaction:1 changing_src:percona.checksums replicate:percona.checksums bidirectional:0 pid:23735 user:root host:at-database1*/;

as can be seen from the output above, deleting one record will
resolve the differences in this particular replication pair. The
information in the comment contains details about how pt-table-sync
determined the need for this change.

To apply needed changes, run pt-table-sync with the `--execute` argument::

    # pt-table-sync --execute --replicate 'percona.checksums' localhost

the command will produce no output during a succesful run.

Alternatively, if desired, the output from the `--print` command
can be manually executed on the replica instead of using pt-table-sync
to do this automatically.

Tuning the `pt-table-checksum` runs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The pt-table-checksum tool uses fairly advanced logic to perform
the checksum, such as monitoring replica lag, chunking tables into subsets
for performance, partial or time-limited checksumming for off-hours use,
resuming partially completed jobs, etc.

Due to the complex heuristics used in pt-table-checksum and the various ways
these cna be adjusted, the time to complete a checksum run can vary greatly 
depending on the parameters used. Some notes on tuning checksum runs follows:

- defaults can result in slow queries and therefore checksums on some tables
  due to over-granularity of checksum chunks
- disabling query plan checking in pt-table-checksum to address this might 
  facillitate faster queries, but could result in spurious load due
  to unoptimized checksum queries
- instead setting only some columns (--chunk-index-columns) can result in
  duplicated chunks (keys are not unique), which breaks checks 
- setting the --chunk-size-limit likely needs a higher value for small 
  record tables which could conversely impact performance on big ones,
  so is not ideal
- as such, setting a higher chunk time heuristic target (`--chunk-time=300`)
  seems ideal for a mixed large/small table workload since it allows the
  heuristicss to run 'normally' but doesn't over-chunk smaller tables.

Also to note for checksum performance is the actual checksum function used,
see :ref:`Percona Toolkit UDFs for pt-table-checksum` for more.

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
 
