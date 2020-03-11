
MySQL User/Account Managment
----------------------------

Create User
~~~~~~~~~~~

For mysql < 8.0, explicit user creation is not required, just issue initial
grant with additional 'identified by "passwordvalue"' clause.  For example::

    mysql> grant all on `username\_%`.* to 'username'@'%' identified by 'foo';

Change Password
~~~~~~~~~~~~~~~

Passwords can be changed in MySQL as follows::

    mysql> set password for 'user'@'%' = password('text password');

another syntax is::

    mysql> UPDATE mysql.user SET Password=PASSWORD('text password') WHERE user=”username” AND Host=”hostname”;

Grant Permission
~~~~~~~~~~~~~~~~

Syntax for grants is as follows::

    mysql> grant PERMISSION on `db`.`tbl` to 'user'@'host';

for example::

    mysql> grant SELECT,REFERENCES on `core`.* to 'user'@'host';

The per-character ('_') wildcard and multi-character wildcard ('%') may
be used to create less specific rules. For databases/tables which include
the '_' character, since the bare '_' is interpreted as a wildcard, the
character should be escaped using backslash e.g.: `fun\_stuff`.

Revoke Permissions
~~~~~~~~~~~~~~~~~~

Syntax for revokes is as follows::

    mysql> revoke PERMISSION on `db`.`tbl` from 'user'@'host';

for example::

    mysql> revoke SELECT,REFERENCES on `core`.* from 'user'@'host';

