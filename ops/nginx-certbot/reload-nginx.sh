#!/bin/sh
# SPDX-FileCopyrightText: 2026 rickytheoldtree
#
# SPDX-License-Identifier: AGPL-3.0-only

set -eu

/usr/bin/docker exec nginx nginx -t >/dev/null 2>&1
/usr/bin/docker exec nginx nginx -s reload >/dev/null 2>&1
