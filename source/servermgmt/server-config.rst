
MySQL Server Configuration
--------------------------

This section covers key mysql server configuration settings and how
to view/modify them. It is not exhaustive. For further reference,
see also live server configuration files and official documentation.

Viewing/Modifying Current Configuration Values
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The 'my_print_defaults' command can be used to retrieve current configuration
values as parsed by the mysql programs for various 'blocks' in the configuration
files::

    # my_print_defaults client
    # my_print_defaults mysql
    # # etc..

To view configuration settings used by a running server, the 'show variables'
and 'show globals' commands can be used::

    mysql> show variables like 'innodb%'; -- innodb related variables
    mysql> show global variables like '%timeout%'; -- timeout global variables
    mysql> -- etc...

To set server variables, the 'set variable' and 'set global' commands can
be used::

    mysql> set wait_timeout=28800; -- set wait timeout (per session)
    mysql> set global wait_timeout=28800; -- set wait timeout (server wide)

As shown in the above example, it's important to remember that
variables may have multiple overlapping configuraiton scopes (e.g.
per-session, global, etc) and each of these may or may not be
dynamically configurable. Non-dynamic variables must be enabled in the
mysql configuration files prior to starting the related programs.

Important Server Configuration Variables
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This section outlines some important server configuration variables
which may need adjustment for large scale installations. Variable
names and a brief note about why it is important is outlined in the
following table. Where needed, a suggested setting is written in
parenthesis. For further details see the appropriate sections of
this document or the mysql reference documentation.

=================================== =========================================
Variable Name                       Notes
=================================== =========================================
log_bin                             required on replication masters
expire_logs_days                    determines working replication window
sync_binlog                         ensures replication logs are coherent
relay_log_recovery                  improves recovery on replication slaves
max_allowed_packet                  needed for large blob fields
thread_pool_size                    number of server threads (nCPU)
max_connections                     number of total allowed connections
tmpdir                              temporary storage, used for large joins
max_heap_table_size                 maximum in-memory temporary table
innodb_buffer_pool_size             key InnoDB memory parameter (75% RAM)
innodb_thread_concurrency           key InnoDB CPU parameter (nCPU)
innodb_thread_sleep_delay           key InnoDB scheduling parameter
innodb_adaptive_max_sleep_delay     key InnoDB scheduling parameter
innodb_concurrency_tickets          key InnoDB scheduling parameter
innodb_log_file_size                key InnoDB transaction configuration
innodb_log_buffer_size              key InnoDB transaction configuration
innodb_stats_on_metadata            keep extra InnoDB table statistics (off)
innodb_file_per_table               key InnoDB storage configuration (on)
innodb_write_io_threads             key InnoDB i/o paremeter (2/3 CPUs)
innodb_read_io_threads              key InnoDB i/o paremeter (1/3 CPUs) 
innodb_flush_log_at_trx_commit      key InnoDB data integrity setting (on)
innodb_lock_wait_timeout            timeout for requesting-cliient locks
innodb_print_lock_wait_timeout_info useful for transaction dbugging
wait_timeout                        inactive client timeout
interactive_timeout                 client timeout if 'interactive' client
net_read_timeout                    timeout for client->server xmit/recv
net_write_timeout                   timeout for server->client xmit/recv
=================================== =========================================

