
Transaction Lock Debugging
--------------------------

This section outlines some ways to view active locks. For issues pertaining
to already expired locks, see the section `Lock Wait Timeout Debugging`_.

Via: 

  - https://stackoverflow.com/questions/13148630/
    how-do-i-find-which-transaction-is-causing-a-waiting-for-table-metadata-lock-s
  - http://abiasforaction.net/debugging-transactional-and-locking-issues-in-mysql/

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

  - A list of transactions/locks/queries pertaining to a specific schema::

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
      WHERE  r.trx_id in (
      Select ID FROM information_schema.processlist where DB='YOUR_DB_NAME') ;
      
  - mysql 5.7 exposes metadata lock information through the
    performance_schema.metadata_locks table.

Lock Wait Timeout Debugging
---------------------------

This section outlines the steps needed for investigating lock wait timeouts
using the MySQL performance schema.

More information on the `performance schema` is availble in the MySQL
reference documentation[#]_ .

Additionally, a tool to watch percona server logs for db-lock timeouts
is available at `https://github.com/vathes/dblock`.

.. [#] https://dev.mysql.com/doc/refman/5.6/en/performance-schema.html

.. todo: include/refile:
.. https://www.percona.com/doc/percona-server/LATEST/diagnostics/innodb_show_status.html
.. https://bugs.launchpad.net/percona-server/+bug/1657737

Configuration
~~~~~~~~~~~~~

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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

Automated Lock Debugging with 'dblock'
--------------------------------------

As seen in the previous sections, using client information to cross
check a lock problem against its cause can be a fairly involved
process whose proper resolution is usually dependent on workload
or data dependent information that the administrator may not be
able to determine without input from users. 

To automate the process of lock debugging and help ensure that users
can be informed about lock issues affecting their work, the 'dblock'
script was written. This script monitors the MySQL error log for
lock wait timeout messages and provides notification of the related
processes and queries invoved. 

The script should run on the actual database server, and requires read
access to the MySQL server error log and to the various information_schema
and performance_schema tables.

More information is available in the dblock sources and in local
system configuration.

