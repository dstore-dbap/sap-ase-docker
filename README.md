# sap-ase-docker

Howto Dockerize SAP (formerly Sybase) Adaptive Server Enterprise (ASE) with regards to image size and some hints
howto perform a scripted database server installation.

## Remarks

  * This repo does not contain any SAP software, you may get a
  free "Developer" or "Express-Edition" of SAP ASE via
  http://scn.sap.com/community/developer-center/oltp-db
  * We delete some directorys (Jconnect, diagserver, SCC, JREs) to keep the image small.
  You may need to edit the Dockerfile yourself if you need some of these components.
  * The ASE server allocates a lot of shared memory. When running docker on 2.x
  Linux-Kernels you may hit a shared memory limit (check limit via `ipcs -lm`).
  To adjust the SHMMAX via `sysctl kernel.shmmax=<value>` extended privileges must be
  granted when the container is started (`--privileged=true`).

## Further steps

Some hints for scripted installation to get a running dataserver

### create master device

Create a master device of 60 MB with 4K-pagesize. This command exits after creation.

    /opt/sybase/ASE-15_0/bin/dataserver \
        -d/opt/datadir/master.dat \
        -b 60M \
        -z 4K \
        -e/opt/datadir/sybase_errorlog \
        -c/opt/datadir/SYBASE.cfg \
        -M/opt/datadir/ \
        -sSYBASE

### startup server

Startup the dataserver and wait until the server comes up (via netcat-tool)

    /opt/sybase/ASE-15_0/bin/dataserver \
        -d/opt/datadir/master.dat \
        -e/opt/datadir/sybase_errorlog \
        -c/opt/datadir/SYBASE.cfg \
        -M/opt/datadir/ \
        -sSYBASE

    while ! echo | nc -4 localhost 5000 > /dev/null 2>&1; do sleep 1; done

## install sybsystemproc

    isql -Usa -P --retserverror -SSYBASE << EOF
    disk init name = "sysprocsdev",
    physname = "/opt/datadir/sysprocsdev",
    size = "180M"
    go
    create database sybsystemprocs on sysprocsdev = 180
    go
    EOF

    isql -Usa -P --retserverror -SSYBASE -n -i $SYBASE/$SYBASE_ASE/scripts/installmaster

## other install scripts

    isql -Usa -P --retserverror -SSYBASE -n -i $SYBASE/$SYBASE_ASE/scripts/installmodel
    isql -Usa -P --retserverror -SSYBASE -n -i $SYBASE/$SYBASE_ASE/scripts/instmsgs.ebf
    isql -Usa -P --retserverror -SSYBASE -n -i $SYBASE/$SYBASE_ASE/scripts/installupgrade

# useful options

    isql -Usa -P -SSYBASE --retserverror -J iso_1 << EOF
    exec sp_configure 'max memory', 384000 -- 750 MB
    exec sp_configure 'enable console logging', 1
    exec sp_configure 'send doneinproc tokens', 0
    exec sp_configure 'number of user connections', 200
    exec sp_configure 'max network packet size', 8192
    exec sp_configure 'enable logins during recovery', 0
    EOF

# changeing charset to UTF-8

    charset -Usa -SSYBASE -P binary.srt utf8

    isql -Usa -P -SSYBASE -J iso_1 << EOF
    sp_configure 'default character set', 190
    go
    sp_configure 'default sortorder id', 50
    go
    shutdown
    go
    EOF

Server needs to be started twice after the `shutdown`, because after
changing the charset the server performs a single-user start, performs translations and exits.

# resizing of tempdb

You may want a larger tempdb

    isql -Usa -P --retserverror -SSYBASE << EOF 
    disk init
    name = "tempdev2",
    physname = "/opt/datadir/tempspace2.dat",
    cntrltype = 0,
    dsync = true,
    size = "500M"
    go
    alter database tempdb on tempdev2 = 500
    go
    exec sp_cacheconfig 'default data cache', '200M'
    go
    EOF