
MariaDB
-------

mariabackup
~~~~~~~~~~~

mariabackup (mariadb's xtrabackup fork)
https://mariadb.com/kb/en/library/mariadb-backup-overview/
apparently needed for mariadb ~10.1.26+ (and definately 10.3) instead
of the percona xtrabackup tool.

Example install/usage::

  # apt-get install mariadb-backup-10.3
  # mariabackup --user=root --password=maria --target-dir=/net/backup --backup
  # mariabackup --target-dir=/net/backup --prepare

Not using mariadb; notes are for reference purposes.
