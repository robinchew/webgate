Instead of running blugate server, can run a test UDS server with socat:
```sh
socat unix-listen:/tmp/mydaemon.sock,fork STDOUT
```
Client
```sh
socat - UNIX-CONNECT:/tmp/mydaemon.sock
```
