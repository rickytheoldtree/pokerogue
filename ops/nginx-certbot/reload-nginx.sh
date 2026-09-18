#!/bin/sh
set -eu

/usr/bin/docker exec nginx nginx -t >/dev/null 2>&1
/usr/bin/docker exec nginx nginx -s reload >/dev/null 2>&1
