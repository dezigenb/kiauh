#!/usr/bin/env bash

#=======================================================================#
# Copyright (C) 2020 - 2024 Dominik Willner <th33xitus@gmail.com>       #
#                                                                       #
# This file is part of KIAUH - Klipper Installation And Update Helper   #
# https://github.com/dw-0/kiauh                                         #
#                                                                       #
# This file may be distributed under the terms of the GNU GPLv3 license #
#=======================================================================#


set -e
clear -x

# make sure we have the correct permissions while running the script
umask 022

### sourcing all additional scripts
KIAUH_SRCDIR="$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")"
for script in "${KIAUH_SRCDIR}/scripts/"*.sh; do . "${script}"; done
for script in "${KIAUH_SRCDIR}/scripts/ui/"*.sh; do . "${script}"; done

function launch_kiauh_v5() {
    main_menu
}

function main() {
  launch_kiauh_v5
}

gitmirror=https://ghproxy.cn/

check_if_ratos
check_euid
init_logfile
set_globals
read_kiauh_ini
init_ini
main