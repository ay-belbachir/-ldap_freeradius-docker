#!/bin/bash
ldapadd -x -D "cn=admin,dc=exemple,dc=local" -w defaultpw -f /usr/local/bin/grpusr.ldif