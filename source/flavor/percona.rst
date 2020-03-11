
Percona Server
--------------

Percona server has several features useful for mysql at scale:

  - 'lock for backup': allows data operations but blocks metadata operations,
    which are less likely to cause wait timeouts.
  - config (FIXME ref) to dump lock wait timeout info to error log
    see lockwait tools/sections.
  - built in functions for faster table checksumming

