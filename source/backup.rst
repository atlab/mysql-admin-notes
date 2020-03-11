
MySQL Server Backup
===================

A variety of tools are available to provide backups for mysql servers.

The simplest is 'mysqlbackup', which is part of the core distribution
of all mysql flavors (oracle, mariadb, percona server). 

A more advanced tool which provides additional support for large or
replicated servers is percona's `innobackup`. This tool allows:

  - low-level (e.g. table format rather than SQL statement) backup
  - incremental backups
  - output of replication related parameters used to assist in building
    database replicas
  - support for percona server lightweight locking (metadata only locks)
    which can alleviate lock contention for long running backup jobs
  - point-in-time backup (e.g. completed backups are current to the time
    of backup completion rather than backup start)
  - streaming backup (e.g. backups streamed into place on a target which
    can be used without performing a full restoration)

One downside of this tool is that due to the support for point-in-time backup,
the backup medium must be performant enough to keep up with ongoing database
write activity (a transaction log is kept while the database is running which
provides the point-in-time data - if this lags too far behind the live
transaction buffers, the backup fails).

A set of wrapper scripts has been written around 'innobbackup' and is
available in the 'dbbak' repository: `https://github.com/atlab/dbbak`.
Currently, this script performs backup/restore for full+incremental backups, 
and supports the notion of a 'current' and 'previous' backup set.

