Rebuilding Slaves from Backup
-----------------------------

use '--slave-info' xtrabackup option - and values in xtrabackup_slave_info
file rather than xtrabackup_binlog_info file. Example:

  # cat xtrabackup_slave_info
  CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.048008', MASTER_LOG_POS=9014377

see also: https://www.percona.com/doc/percona-xtrabackup/2.1/howtos/setting_up_replication.html#adding-more-slaves-to-the-master

The 'dbbak' script includes this argument during runs.
