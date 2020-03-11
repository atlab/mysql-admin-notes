
MySQL Server Timeout Values
---------------------------

    wait_timeout: inactive client timeout
    interactive_timeout: inactive timeout if 'CLIENT_INTERACTIVE' option set
    net_read_timeout: timeout for client->server data xmit/recv
    net_write_timeout: timeout for server->client data xmit/recv

    int(conn.query("show variables like 'net_read_timeout'").fetchall()[0][1])  # 60
    conn.query("set session net_read_timeout=90").fetchall()  # ()

    int(conn.query("show variables like 'net_write_timeout'").fetchall()[0][1])
    conn.query("set session net_read_timeout=90").fetchall()

.. see also: https://blog.pythian.com/connection-timeout-parameters-mysql/

