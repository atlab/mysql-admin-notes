LVM Database Snapshots of DB Instances
--------------------------------------

To create online snapshots of a database using LVM snapshots, the following
steps can be taken (requires the database volume be stored on an LVM partition)

1) Stop database write activity.

   To ensure that the LVM snapshot is created from a valid on-disk state,
   database write activity should be stopped prior to taking the snapshot.
   This should be done from a mysql session as follows::

     mysql> stop replication; -- if applicable
     mysql> flush tables with read lock;

   The MySQL session should be kept open for the subsequent step which
   creates the actual LVM snapshot.

2) Create LVM Snapshot

   First, ensure data is fully written to disk::

     # sync; # not 100% sure if this is required - lvm may ensure this..

   Create the LVM snapshot as follows::

     # lvcreate -L4T -s -n dblv1-snap /dev/dbvg1/dblv1

   This creates a snapshot with 4TB of delta/working space from dblv1
   called dblv1-snap. The delta space is used to track changes from
   the underlying LVM volume; once the two differ by more than this space
   the snapshot becomes invalid.

3) Reenable database write activity.

   To reenable write activity and replication, the steps performed in step
   #1 should be reversed as follows::

     mysql> unlock tables;
     mysql> start slave; -- if applicable

From here, the snapshot volume can be mounted and used for backups or
running a secondary MySQL instance for debugging / testing, etc.

