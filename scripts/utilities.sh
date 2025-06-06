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

#================================================#
#=================== STARTUP ====================#
#================================================#

function check_euid() {
  if [[ ${EUID} -eq 0 ]]; then
    echo -e "${red}"
    top_border
    echo -e "|       !!! THIS SCRIPT MUST NOT RUN AS ROOT !!!        |"
    echo -e "|                                                       |"
    echo -e "|        It will ask for credentials as needed.         |"
    bottom_border
    echo -e "${white}"
    exit 1
  fi
}

function check_if_ratos() {
  if [[ -n $(which ratos) ]]; then
    echo -e "${red}"
    top_border
    echo -e "|        !!! RatOS 2.1 or greater detected !!!          |"
    echo -e "|                                                       |"
    echo -e "|        KIAUH does currently not support RatOS.        |"
    echo -e "| If you have any questions, please ask for help on the |"
    echo -e "| RatRig Community Discord: https://discord.gg/ratrig   |"
    bottom_border
    echo -e "${white}"
    exit 1
  fi
}

#================================================#
#============= MESSAGE FORMATTING ===============#
#================================================#

function select_msg() {
  echo -e "${white}   [➔] ${1}"
}
function status_msg() {
  echo -e "\n${magenta}###### ${1}${white}"
}
function ok_msg() {
  echo -e "${green}[✓ OK] ${1}${white}"
}
function warn_msg() {
  echo -e "${yellow}>>>>>> ${1}${white}"
}
function error_msg() {
  echo -e "${red}>>>>>> ${1}${white}"
}
function abort_msg() {
  echo -e "${red}<<<<<< ${1}${white}"
}
function title_msg() {
  echo -e "${cyan}${1}${white}"
}

function print_error() {
  [[ -z ${1} ]] && return

  echo -e "${red}"
  echo -e "#=======================================================#"
  echo -e " ${1} "
  echo -e "#=======================================================#"
  echo -e "${white}"
}

function print_confirm() {
  [[ -z ${1} ]] && return

  echo -e "${green}"
  echo -e "#=======================================================#"
  echo -e " ${1} "
  echo -e "#=======================================================#"
  echo -e "${white}"
}

#================================================#
#=================== LOGGING ====================#
#================================================#

function timestamp() {
  date +"[%F %T]"
}

function init_logfile() {
  local log="/tmp/kiauh.log"
  {
    echo -e "#================================================================#"
    echo -e "# New KIAUH session started on: $(date) #"
    echo -e "#================================================================#"
    echo -e "KIAUH $(get_kiauh_version)"
    echo -e "#================================================================#"
  } >> "${log}"
}

function log_info() {
  local message="${1}" log="${LOGFILE}"
  echo -e "$(timestamp) [INFO]: ${message}" | tr -s " " >> "${log}"
}

function log_warning() {
  local message="${1}" log="${LOGFILE}"
  echo -e "$(timestamp) [WARN]: ${message}" | tr -s " " >> "${log}"
}

function log_error() {
  local message="${1}" log="${LOGFILE}"
  echo -e "$(timestamp) [ERR]: ${message}" | tr -s " " >> "${log}"
}

#================================================#
#=============== KIAUH SETTINGS =================#
#================================================#

function read_kiauh_ini() {
  local func=${1}

  if [[ ! -f ${INI_FILE} ]]; then
    log_warning "Reading from .kiauh.ini failed! File not found! Creating default ini file."
    init_ini
  fi

  log_info "Reading from .kiauh.ini ... (${func})"
  source "${INI_FILE}"
}

function init_ini() {
  ### remove pre-version 4 ini files
  if [[ -f ${INI_FILE} ]] && ! grep -Eq "^# KIAUH v4\.0\.0$" "${INI_FILE}"; then
    rm "${INI_FILE}"
  fi

  ### initialize v4.0.0 ini file
  if [[ ! -f ${INI_FILE} ]]; then
    {
      echo -e "# File creation date: $(date)"
      echo -e "#=================================================#"
      echo -e "# KIAUH - Klipper Installation And Update Helper  #"
      echo -e "#       https://github.com/dw-0/kiauh             #"
      echo -e "#             DO NOT edit this file!              #"
      echo -e "#=================================================#"
      echo -e "# KIAUH v4.0.0"
      echo -e "#"
    } >> "${INI_FILE}"
  fi

  if ! grep -Eq "^application_updates_available=" "${INI_FILE}"; then
    echo -e "\napplication_updates_available=\c" >> "${INI_FILE}"
  else
    sed -i "/application_updates_available=/s/=.*/=/" "${INI_FILE}"
  fi

  if ! grep -Eq "^backup_before_update=." "${INI_FILE}"; then
    echo -e "\nbackup_before_update=false\c" >> "${INI_FILE}"
  fi

  if ! grep -Eq "^logupload_accepted=." "${INI_FILE}"; then
    echo -e "\nlogupload_accepted=false\c" >> "${INI_FILE}"
  fi

  if ! grep -Eq "^custom_klipper_repo=" "${INI_FILE}"; then
    echo -e "\ncustom_klipper_repo=\c" >> "${INI_FILE}"
  fi

  if ! grep -Eq "^custom_klipper_repo_branch=" "${INI_FILE}"; then
    echo -e "\ncustom_klipper_repo_branch=\c" >> "${INI_FILE}"
  fi

  if ! grep -Eq "^mainsail_install_unstable=" "${INI_FILE}"; then
    echo -e "\nmainsail_install_unstable=false\c" >> "${INI_FILE}"
  fi

  if ! grep -Eq "^fluidd_install_unstable=" "${INI_FILE}"; then
    echo -e "\nfluidd_install_unstable=false\c" >> "${INI_FILE}"
  fi

  if ! grep -Eq "^multi_instance_names=" "${INI_FILE}"; then
    echo -e "\nmulti_instance_names=\c" >> "${INI_FILE}"
  fi

  if ! grep -Eq "^version_to_launch=" "${INI_FILE}"; then
    echo -e "\nversion_to_launch=\n\c" >> "${INI_FILE}"
  fi

  ### strip all empty lines out of the file
  sed -i "/^[[:blank:]]*$/ d" "${INI_FILE}"
}

function switch_mainsail_releasetype() {
  read_kiauh_ini "${FUNCNAME[0]}"
  local state="${mainsail_install_unstable}"

  if [[ ${state} == "false" ]]; then
    sed -i '/mainsail_install_unstable=/s/false/true/' "${INI_FILE}"
    log_info "mainsail_install_unstable changed (false -> true) "
  else
    sed -i '/mainsail_install_unstable=/s/true/false/' "${INI_FILE}"
    log_info "mainsail_install_unstable changed (true -> false) "
  fi
}

function switch_fluidd_releasetype() {
  read_kiauh_ini "${FUNCNAME[0]}"
  local state="${fluidd_install_unstable}"

  if [[ ${state} == "false" ]]; then
    sed -i '/fluidd_install_unstable=/s/false/true/' "${INI_FILE}"
    log_info "fluidd_install_unstable changed (false -> true) "
  else
    sed -i '/fluidd_install_unstable=/s/true/false/' "${INI_FILE}"
    log_info "fluidd_install_unstable changed (true -> false) "
  fi
}

function toggle_backup_before_update() {
  read_kiauh_ini "${FUNCNAME[0]}"
  local state="${backup_before_update}"

  if [[ ${state} = "false" ]]; then
    sed -i '/backup_before_update=/s/false/true/' "${INI_FILE}"
  else
    sed -i '/backup_before_update=/s/true/false/' "${INI_FILE}"
  fi
}

function set_custom_klipper_repo() {
  read_kiauh_ini "${FUNCNAME[0]}"
  local repo=${1} branch=${2}

  sed -i "/^custom_klipper_repo=/d" "${INI_FILE}"
  sed -i '$a'"custom_klipper_repo=${repo}" "${INI_FILE}"
  sed -i "/^custom_klipper_repo_branch=/d" "${INI_FILE}"
  sed -i '$a'"custom_klipper_repo_branch=${branch}" "${INI_FILE}"
}

function add_to_application_updates() {
  read_kiauh_ini "${FUNCNAME[0]}"

  local application="${1}"
  local app_update_state="${application_updates_available}"

  if ! grep -Eq "${application}" <<< "${app_update_state}"; then
    app_update_state="${app_update_state}${application},"
    sed -i "/application_updates_available=/s/=.*/=${app_update_state}/" "${INI_FILE}"
  fi
}

#================================================#
#=============== HANDLE SERVICES ================#
#================================================#

function do_action_service() {
  local services action=${1} service=${2}
  services=$(find "${SYSTEMD}" -maxdepth 1 -regextype posix-extended -regex "${SYSTEMD}/${service}(-[0-9a-zA-Z]+)?.service" | sort)

  if [[ -n ${services} ]]; then
    for service in ${services}; do
      service=$(echo "${service}" | rev | cut -d"/" -f1 | rev)
      status_msg "${action^} ${service} ..."

      if sudo systemctl "${action}" "${service}"; then
        log_info "${service}: ${action} > success"
        ok_msg "${action^} ${service} successfull!"
      else
        log_warning "${service}: ${action} > failed"
        warn_msg "${action^} ${service} failed!"
      fi
    done
  fi
}

#================================================#
#================ DEPENDENCIES ==================#
#================================================#

### returns 'true' if python version >= 3.7
function python3_check() {
  local major minor passed

  major=$(python3 --version | cut -d" " -f2 | cut -d"." -f1)
  minor=$(python3 --version | cut -d"." -f2)

  if (( major >= 3 && minor >= 7 )); then
    passed="true"
  else
    passed="false"
  fi

  echo "${passed}"
}

function dependency_check() {
  local dep=( "${@}" )
  local packages log_name="dependencies"
  status_msg "Checking for the following dependencies:"

  #check if package is installed, if not write its name into array
  for pkg in "${dep[@]}"; do
    echo -e "${cyan}● ${pkg} ${white}"
    [[ ! $(dpkg-query -f'${Status}' --show "${pkg}" 2>/dev/null) = *\ installed ]] && \
    packages+=("${pkg}")
  done

  #if array is not empty, install packages from array
  if (( ${#packages[@]} > 0 )); then
    status_msg "Installing the following dependencies:"
    for package in "${packages[@]}"; do
      echo -e "${cyan}● ${package} ${white}"
    done
    echo

    # update system package lists if stale
    update_system_package_lists

    # install required packages
    install_system_packages "${log_name}" "packages[@]"

  else
    ok_msg "Dependencies already met!"
    return
  fi
}

function fetch_webui_ports() {
  local port interfaces=("mainsail" "fluidd" "octoprint")

  ### read ports from possible installed interfaces and write them to ~/.kiauh.ini
  for interface in "${interfaces[@]}"; do
    if [[ -f "/etc/nginx/sites-available/${interface}" ]]; then
      port=$(grep -E "listen" "/etc/nginx/sites-available/${interface}" | head -1 | sed 's/^\s*//' | sed 's/;$//' | cut -d" " -f2)
      if ! grep -Eq "${interface}_port" "${INI_FILE}"; then
        sed -i '$a'"${interface}_port=${port}" "${INI_FILE}"
      else
        sed -i "/^${interface}_port/d" "${INI_FILE}"
        sed -i '$a'"${interface}_port=${port}" "${INI_FILE}"
      fi
    else
        sed -i "/^${interface}_port/d" "${INI_FILE}"
    fi
  done
}

#================================================#
#=================== SYSTEM =====================#
#================================================#

function create_required_folders() {
  local printer_data=${1} folders
  folders=("backup" "certs" "config" "database" "gcodes" "comms" "logs" "systemd")

  for folder in "${folders[@]}"; do
    local dir="${printer_data}/${folder}"

    ### remove possible symlink created by moonraker
    if [[ -L "${dir}" && -d "${dir}" ]]; then
      rm "${dir}"
    fi

    if [[ ! -d "${dir}" ]]; then
      status_msg "Creating folder '${dir}' ..."
      mkdir -p "${dir}"
      ok_msg "Folder '${dir}' created!"
    fi
  done
}

function update_system_package_lists() {
  local cache_mtime update_age update_interval silent

  if [[ $1 == '--silent' ]]; then silent="true"; fi

  if [[ -e /var/lib/apt/periodic/update-success-stamp ]]; then
    cache_mtime="$(stat -c %Y /var/lib/apt/periodic/update-success-stamp)"
  elif [[ -e /var/lib/apt/lists ]]; then
    cache_mtime="$(stat -c %Y /var/lib/apt/lists)"
  else
    log_warning "Failure determining package cache age, forcing update"
    cache_mtime=0
  fi

  update_age="$(($(date +'%s') - cache_mtime))"
  update_interval=$((48*60*60)) # 48hrs

  # update if cache is greater than update_interval
  if (( update_age > update_interval )); then
    if [[ ! ${silent} == "true" ]]; then status_msg "Updating package lists..."; fi
    if ! sudo apt-get update --allow-releaseinfo-change &>/dev/null; then
      log_error "Failure while updating package lists!"
      if [[ ! ${silent} == "true" ]]; then error_msg "Updating package lists failed!"; fi
      return 1
    else
      log_info "Package lists updated successfully"
      if [[ ! ${silent} == "true" ]]; then status_msg "Updated package lists."; fi
    fi
  else
    log_info "Package lists updated recently, skipping update..."
  fi
}

function check_system_updates() {
  local updates_avail status
  if ! update_system_package_lists --silent; then
    status="${red}Update check failed!     ${white}"
  else
    updates_avail="$(apt list --upgradeable 2>/dev/null | sed "1d")"

    if [[ -n ${updates_avail} ]]; then
      status="${yellow}System upgrade available!${white}"
      # add system to application_updates_available in kiauh.ini
      add_to_application_updates "system"
    else
      status="${green}System up to date!       ${white}"
    fi
  fi

  echo "${status}"
}

function upgrade_system_packages() {
  status_msg "Upgrading System ..."
  update_system_package_lists
  if sudo apt-get upgrade -y; then
    print_confirm "Upgrade complete! Check the log above!\n ${yellow}KIAUH will not install any dist-upgrades or\n any packages which have been held back!${green}"
  else
    print_error "System upgrade failed! Please look for any errors printed above!"
  fi
}

function install_system_packages() {
  local log_name="$1"
  local packages=("${!2}")
  status_msg "Installing packages..."
  if sudo apt-get install -y "${packages[@]}"; then
    ok_msg "${log_name^} packages installed!"
  else
    log_error "Failure while installing ${log_name,,} packages"
    error_msg "Installing ${log_name} packages failed!"
    exit 1 # exit kiauh
  fi
}

function check_usergroups() {
  local group_dialout group_tty

  if grep -q "dialout" </etc/group && ! grep -q "dialout" <(groups "${USER}"); then
    group_dialout="false"
  fi

  if grep -q "tty" </etc/group && ! grep -q "tty" <(groups "${USER}"); then
    group_tty="false"
  fi

  if [[ ${group_dialout} == "false" || ${group_tty} == "false" ]] ; then
    top_border
    echo -e "| ${yellow}WARNING: Your current user is not in group:${white}           |"
    [[ ${group_tty} == "false" ]] && \
    echo -e "| ${yellow}● tty${white}                                                 |"
    [[ ${group_dialout} == "false" ]] && \
    echo -e "| ${yellow}● dialout${white}                                             |"
    blank_line
    echo -e "| It is possible that you won't be able to successfully |"
    echo -e "| connect and/or flash the controller board without     |"
    echo -e "| your user being a member of that group.               |"
    echo -e "| If you want to add the current user to the group(s)   |"
    echo -e "| listed above, answer with 'Y'. Else skip with 'n'.    |"
    blank_line
    echo -e "| ${yellow}INFO:${white}                                                 |"
    echo -e "| ${yellow}Relog required for group assignments to take effect!${white}  |"
    bottom_border

    local yn
    while true; do
      yn="y"
      #read -p "${cyan}###### Add user '${USER}' to group(s) now? (Y/n):${white} " yn
      case "${yn}" in
        Y|y|Yes|yes|"")
          select_msg "Yes"
          status_msg "Adding user '${USER}' to group(s) ..."
          if [[ ${group_tty} == "false" ]]; then
            sudo usermod -a -G tty "${USER}" && ok_msg "Group 'tty' assigned!"
          fi
          if [[ ${group_dialout} == "false" ]]; then
            sudo usermod -a -G dialout "${USER}" && ok_msg "Group 'dialout' assigned!"
          fi
          ok_msg "Remember to relog/restart this machine for the group(s) to be applied!"
          break;;
        N|n|No|no)
          select_msg "No"
          break;;
        *)
          print_error "Invalid command!";;
      esac
    done
  fi
}

function set_custom_hostname() {
  echo
  top_border
  echo -e "|  Changing the hostname of this machine allows you to  |"
  echo -e "|  access a webinterface that is configured for port 80 |"
  echo -e "|  by simply typing '<hostname>.local' in the browser.  |"
  echo -e "|                                                       |"
  echo -e "|  E.g.: If you set the hostname to 'my-printer' you    |"
  echo -e "|        can open Mainsail / Fluidd / Octoprint by      |"
  echo -e "|        browsing to: http://my-printer.local           |"
  bottom_border

  local yn
  while true; do
    read -p "${cyan}###### Do you want to change the hostname? (y/N):${white} " yn
    case "${yn}" in
      Y|y|Yes|yes)
        select_msg "Yes"
        change_hostname
        break;;
      N|n|No|no|"")
        select_msg "No"
        break;;
      *)
        error_msg "Invalid command!";;
    esac
  done
}

function change_hostname() {
    local new_hostname regex="^[^\-\_]+([0-9a-z]\-{0,1})+[^\-\_]+$"
    echo
    top_border
    echo -e "|  ${green}Allowed characters: a-z, 0-9 and single '-'${white}          |"
    echo -e "|  ${red}No special characters allowed!${white}                       |"
    echo -e "|  ${red}No leading or trailing '-' allowed!${white}                  |"
    bottom_border

    while true; do
      read -p "${cyan}###### Please set the new hostname:${white} " new_hostname

      if [[ ${new_hostname} =~ ${regex} ]]; then
        local yn
        while true; do
          echo
          read -p "${cyan}###### Do you want '${new_hostname}' to be the new hostname? (Y/n):${white} " yn
          case "${yn}" in
            Y|y|Yes|yes|"")
              select_msg "Yes"
              set_hostname "${new_hostname}"
              break;;
            N|n|No|no)
              select_msg "No"
              abort_msg "Skip hostname change ..."
              break;;
            *)
              print_error "Invalid command!";;
          esac
        done
      else
        warn_msg "'${new_hostname}' is not a valid hostname!"
      fi
      break
    done
}

function set_hostname() {
  local new_hostname=${1} current_date
  #check for dependencies
  local dep=(avahi-daemon)
  dependency_check "${dep[@]}"

  #create host file if missing or create backup of existing one with current date&time
  if [[ -f /etc/hosts ]]; then
    current_date=$(get_date)
    status_msg "Creating backup of hosts file ..."
    sudo cp "/etc/hosts" "/etc/hosts.${current_date}.bak"
    ok_msg "Backup done!"
    ok_msg "File:'/etc/hosts.${current_date}.bak'"
  else
    sudo touch /etc/hosts
  fi

  #set new hostname in /etc/hostname
  status_msg "Setting hostname to '${new_hostname}' ..."
  status_msg "Please wait ..."
  sudo hostnamectl set-hostname "${new_hostname}"

  #write new hostname to /etc/hosts
  status_msg "Writing new hostname to /etc/hosts ..."
  echo "127.0.0.1       ${new_hostname}" | sudo tee -a /etc/hosts &>/dev/null
  ok_msg "New hostname successfully configured!"
  ok_msg "Remember to reboot for the changes to take effect!"
}

#================================================#
#============ INSTANCE MANAGEMENT ===============#
#================================================#

###
# takes in a systemd service files full path and
# returns the sub-string with the instance name
#
# @param {string}: service file absolute path
#                  (e.g. '/etc/systemd/system/klipper-<name>.service')
#
# => return sub-string containing only the <name> part of the full string
#
function get_instance_name() {
  local instance=${1}
  local name

  name=$(echo "${instance}" | rev | cut -d"/" -f1 | cut -d"." -f2 | cut -d"-" -f1 | rev)

  echo "${name}"
}

###
# returns the instance name/identifier of the klipper service
# if the klipper service is part of a multi instance setup
# otherwise returns an emtpy string
#
# @param {string}: name - klipper service name (e.g. klipper-name.service)
#
function get_klipper_instance_name() {
  local instance=${1}
  local name

  name=$(echo "${instance}" | rev | cut -d"/" -f1 | cut -d"." -f2 | rev)

  local regex="^klipper-[0-9a-zA-Z]+$"
  if [[ ${name} =~ ${regex} ]]; then
    name=$(echo "${name}" | cut -d"-" -f2)
  else
    name=""
  fi

  echo "${name}"
}

###
# loops through all installed klipper services and saves
# each instances name in a comma separated format to the kiauh.ini
#
function set_multi_instance_names() {
  read_kiauh_ini "${FUNCNAME[0]}"

  local name
  local names=""
  local services

  services=$(klipper_systemd)

  ###
  # if value of 'multi_instance_names' is not an empty
  # string, delete its value, so it can be re-written
  if [[ -n ${multi_instance_names} ]]; then
    sed -i "/multi_instance_names=/s/=.*/=/" "${INI_FILE}"
  fi

  for svc in ${services}; do
    name=$(get_klipper_instance_name "${svc}")

    if ! grep -Eq "${name}" <<<"${names}"; then
      names="${names}${name},"
    fi

  done

  # write up-to-date instance name string to kiauh.ini
  sed -i "/multi_instance_names=/s/=.*/=${names}/" "${INI_FILE}"
}

###
# Helper function that returns all configured instance names
#
# => return an empty string if 0 or 1 klipper instance is installed
# => return space-separated string for names of the configured instances
#           if 2 or more klipper instances are installed
#
function get_multi_instance_names() {
  read_kiauh_ini "${FUNCNAME[0]}"
  local instance_names=()

  ###
  # convert the comma separates string from the .kiauh.ini into
  # an array of instance names. a single instance installation
  # results in an empty instance_names array
  IFS=',' read -r -a instance_names <<< "${multi_instance_names}"

  echo "${instance_names[@]}"
}

###
# helper function that returns all possibly available absolute
# klipper config directory paths based on their instance name.
#
# => return an empty string if klipper is not installed
# => return space-separated string of absolute config directory paths
#
function get_config_folders() {
  local cfg_dirs=()
  local instance_names
  instance_names=$(get_multi_instance_names)

  if [[ -n ${instance_names} ]]; then
    for name in ${instance_names}; do
      ###
      # by KIAUH convention, all instance names of only numbers
      # need to be prefixed with 'printer_'
      if [[ ${name} =~ ^[0-9]+$ ]]; then
        cfg_dirs+=("${HOME}/printer_${name}_data/config")
      else
        cfg_dirs+=("${HOME}/${name}_data/config")
      fi
    done
  elif [[ -z ${instance_names} && $(klipper_systemd | wc -w) -gt 0 ]]; then
    cfg_dirs+=("${HOME}/printer_data/config")
  else
    cfg_dirs=()
  fi

  echo "${cfg_dirs[@]}"
}

###
# helper function that returns all available absolute directory paths
# based on their instance name and specified target folder
#
# @param {string}: folder name - target instance folder name (e.g. config)
#
# => return an empty string if klipper is not installed
# => return space-separated string of absolute directory paths
#
function get_instance_folder_path() {
  local folder_name=${1}
  local folder_paths=()
  local instance_names
  local path

  instance_names=$(get_multi_instance_names)

  if [[ -n ${instance_names} ]]; then
    for name in ${instance_names}; do
      ###
      # by KIAUH convention, all instance names of only numbers
      # need to be prefixed with 'printer_'
      if [[ ${name} =~ ^[0-9]+$ ]]; then
        path="${HOME}/printer_${name}_data/${folder_name}"
        if [[ -d ${path} ]]; then
          folder_paths+=("${path}")
        fi
      else
        path="${HOME}/${name}_data/${folder_name}"
        if [[ -d ${path} ]]; then
          folder_paths+=("${path}")
        fi
      fi
    done
  elif [[ -z ${instance_names} && $(klipper_systemd | wc -w) -gt 0 ]]; then
    path="${HOME}/printer_data/${folder_name}"
    if [[ -d ${path} ]]; then
      folder_paths+=("${path}")
    fi
  fi

  echo "${folder_paths[@]}"
}
