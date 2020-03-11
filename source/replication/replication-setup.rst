
Master-Slave Replication
------------------------

Generic notes for setting up master/slave replication, taken from test session
using ubuntu 16.04 virtual machines.

Prepare Master for Replication
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On the master server ensure the server is listening for remote connnections,
has a unique server id, keeps binlogs and stores them in the safest manner, 
has a fresh backup, and a replication user is available::

    # egrep '(bind-address|server-id|log_bin|sync_binlog)' \
      /etc/mysql/mariadb.conf.d/50-server.cnf
    log_bin 			= log-bin
    bind-address		= 0.0.0.0
    server-id			= 1
    sync-binlog			= 1
    # service mysql start
    # innobackupex /data/bkup
    # innobackupex --apply-log /data/bkup/2018-02-20_19-26-46/
    # ufw allow 3306;
    # mysql -u root
    mysql> -- technically only replication related required
    mysql> -- additional permissions needed for pt-table-checksum
    mysql> GRANT SELECT, PROCESS, SUPER, REPLICATION SLAVE, REPLICATION CLIENT
           ON *.* TO 'replication'@'%' IDENTIFIED BY PASSWORD 'replication';
    mysql> flush privileges;

Prepare Slave for Replication
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On the slave server ensure the server is listening for remote connections,
has a unique server id, and is loaded with the fresh backup::

On the slave server::

    # egrep '(bind-address|server-id)' \
      /etc/mysql/mariadb.conf.d/50-server.cnf
    bind-address		= 0.0.0.0
    server-id			= 2
    # ufw allow 3306;
    # service mysql stop
    # rsync -avHS --delete /data/bkup/2018-02-20_19-26-46/ /var/lib/mysql/
    # chown -R mysql:mysql /var/lib/mysql/
    # service mysql start

Enable Replication on Slave
~~~~~~~~~~~~~~~~~~~~~~~~~~~

On the slave server, enable the replication client::

    # binlog=`awk '{print $1}' /var/lib/mysql/xtrabackup_binlog_info`
    # binpos=`awk '{print $2}' /var/lib/mysql/xtrabackup_binlog_info`
    # cat |mysql -u root <<EOF
    CHANGE MASTER TO
    MASTER_HOST='172.28.128.11',
    MASTER_USER='replication',
    MASTER_PASSWORD='replication',
    MASTER_LOG_FILE='$binlog',
    MASTER_LOG_POS=$binpos;
    EOF
    # mysql
    mysql> start slave;
    mysql> show slave status;

Managing Replication Status
~~~~~~~~~~~~~~~~~~~~~~~~~~~

To see binlog position on the master::

    mysql> show master status; 

To see slave replication status on the slave::

    mysql> show slave status;

To reset slave status (needed for some recovery situtations e.g. to 
radically advance replication log pointer)::

    mysql> stop slave;
    mysql> reset slave all;

