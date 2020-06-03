
Percona Server
--------------

Percona server has several features useful for mysql at scale:

  - 'lock for backup': allows data operations but blocks metadata operations,
    which are less likely to cause problematic wait timeouts since they are 
    infrequently used and usually don't impact 'normal' operation.
  - 'innodb_print_lock_wait_timeout_info' to dump lock wait timeout info 
    to the server error log (see also: :ref:`Lock Wait Timeout Debugging`)
  - built in functions such as fnv1a_64 for faster data/table checksumming 
    (see also: :ref:`Replication`)

