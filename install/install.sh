#!/bin/bash
set -e
set -u

title="Linux Log Generator - Installer"
author="theAlistairRoss"

# Set colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [[ -t 1 ]]; then
    # Output is a terminal, use color
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    NC=$(tput sgr0)
else
    # Output is not a terminal, don't use color
    RED=""
    GREEN=""
    NC=""
fi


len=${#title}
divider=$(printf '%*s' "$len" '' | tr ' ' '-')

echo -e "${BLUE}$title${NC}"
echo -e "Author: ${BLUE}@theAlistairRoss${NC}"
echo -e "${BLUE}$divider${NC}"

# Set variables

script_name="log_simulator.py"
service_name="log_simulator.service"
config_name="config.ini"

script_dir=$(dirname "$0")
source_path="$script_dir/../src"
destination_path_to_log_simulator="/opt/log_simulator"
destination_path_to_service_file="/etc/systemd/system"
required_minimum_python_version="3.8"

# Set default values
uninstall=false
install_as_service=false

# Functions
# Parse arguments
parse_arguments() {
    while getopts ":ihu" opt; do
        case ${opt} in
            i ) 
                install_as_service=true
                echo "Install as service option selected. install_as_service=$install_as_service"
                ;;
            h ) 
                display_help
                ;;
            u ) 
                uninstall=true
                echo "Uninstall option selected. uninstall=$uninstall"
                ;;
            \? ) 
                echo -e "${RED}Invalid option: $OPTARG${NC}" 1>&2
                display_help
                ;;
        esac
    done
}

# Check if script is run with sudo
check_root() {
    echo -e "${NC}Checking sudo${NC}" 1>&2

    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}This script must be run as root${NC}" 1>&2
       exit 1
    fi
}

# Display help message
display_help() {
    echo
    echo "This script installs the log simulator on a Linux machine. It can install the script and set it to run as a service to run on boot. It also includes the option to uninstall."
    echo "Usage: $0 [option...]" >&2
    echo
    echo "   -i, --install_as_service   Install the script as a service (default = false)"
    echo "   -h, --help                 Display this help message"
    echo "   -u, --uninstall            Uninstall the script as a service"
    echo
    exit 1
}


# Check file or directory exists function.
check_file_or_directory_exists() {
    local file_or_directory=$1
    if [ -f "$file_or_directory" ] || [ -d "$file_or_directory" ]; then
        return 0
    else
        echo -e "${YELLOW}File or directory not found: $file_or_directory${NC}"
        return 1
    fi
}

# Check if apt-get is installed function
check_apt_get() {
    echo "${NC}Checking apt-get${NC}"
    if ! command -v apt-get &> /dev/null
    then
        echo -e "${RED}This script requires apt-get but it's not installed. Are you sure you're running a Debian-based distribution?${NC}" 1>&2
        exit 1
    fi
    echo -e "${GREEN}apt-get is installed${NC}"
}

# Function to check if a string is a valid floating point number
is_float() {
    local num=$1
    [[ $num =~ ^[+-]?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$ ]]
    return $?
}

# Check if Python is installed function and if it is the correct minimum version
check_python() {
    echo "${NC}Checking Python${NC}"
    if ! command -v python3 &> /dev/null
    then
        echo -e "${RED}Python3 is not installed${NC}" 1>&2
        exit 1
    else
        python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        if ! is_float "$python_version"; then
            echo -e "${RED}Error: python_version is not a valid floating point number${NC}" 1>&2
            exit 1
        fi
        if ! is_float "$required_minimum_python_version"; then
            echo -e "${RED}Error: required_minimum_python_version is not a valid floating point number${NC}" 1>&2
            exit 1
        fi
        if [ $(echo "$python_version >= $required_minimum_python_version" | bc -l) -ne 1 ]; then
            echo -e "${RED}Python3 version $required_minimum_python_version or greater is required${NC}" 1>&2
            exit 1
        else
            echo -e "${GREEN}Python3 version $python_version installed${NC}"
            return 0
        fi
    fi
}

# Make the Python script executable function
make_script_executable() {
    echo -e "${NC}Making the Python script executable${NC}"
    
    check_file_or_directory_exists "$source_path/$script_name"
    if [ $? -ne 0 ]; then
        echo -e "${RED}File or directory does not exist: $source_path/$script_name${NC}" 1>&2
        exit 1
    fi

    chmod +x "$source_path/$script_name"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to make script executable${NC}" 1>&2
        exit 1
    else
        echo -e "${GREEN}Successfully made script executable${NC}"
    fi
}

# Check if a directory exists from a file path and if it doesn't create it function
check_directory_exists_and_create() {
    local file_path=$1
    if [ ! -d "$(dirname "$file_path")" ]; then
        echo -e "${NC}Creating directory $(dirname "$file_path")${NC}"
        mkdir -p "$(dirname "$file_path")"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to create directory $(dirname "$file_path")${NC}" 1>&2
            exit 1
        else
            echo -e "${GREEN}Successfully created directory $(dirname "$file_path")${NC}"
        fi
    fi
}

# Create a copy files function that accepts a source and destination path
copy_files() {
    local source_path=$1
    local destination_path=$2
    echo -e "${NC}Copying $source_path to $destination_path${NC}"
    sudo cp "$source_path" "$destination_path"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to copy file${NC}" 1>&2
        exit 1
    else
        echo -e "${GREEN}Successfully copied file${NC}"
    fi
}

# Copy script files
copy_script_files() {
    declare -A files_to_copy=(
        ["$source_path/$script_name"]="$destination_path_to_log_simulator/$script_name"
        ["$source_path/$config_name"]="$destination_path_to_log_simulator/$config_name"
    )
    for src_path in "${!files_to_copy[@]}"; do
        check_directory_exists_and_create "${files_to_copy[$src_path]}"
        copy_files "$src_path" "${files_to_copy[$src_path]}"
    done
}

# Copy service files
copy_service_files() {
    declare -A files_to_copy=(
        ["$source_path/$service_name"]="$destination_path_to_service_file/$service_name"
    )
    for src_path in "${!files_to_copy[@]}"; do
        copy_files "$src_path" "${files_to_copy[$src_path]}"
    done
}

# Remove the service file function
remove_service_file() {
    echo -e "${NC}Removing $destination_path_to_service_file${NC}"
    sudo rm "$destination_path_to_service_file"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to remove service file${NC}" 1>&2
        exit 1
    else
        echo -e "${GREEN}Successfully removed service file${NC}"
    fi
}

# Reload the systemd daemon function
reload_systemd() {
    echo -e "${NC}Reloading systemd daemon${NC}"
    sudo systemctl daemon-reload
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to reload systemd daemon${NC}" 1>&2
        exit 1
    fi
}

# Start the service function
start_service() {
    echo -e "${NC}Starting log_simulator daemon${NC}"
    sudo systemctl start log_simulator
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to start daemon${NC}" 1>&2
        exit 1
    else
        echo -e "${GREEN}Successfully started daemon${NC}"
    fi
}

# Stop the service function
stop_service() {
    echo -e "${NC}Stopping log_simulator daemon${NC}"
    sudo systemctl stop log_simulator
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to stop daemon${NC}" 1>&2
        exit 1
    else
        echo -e "${GREEN}Successfully stopped daemon${NC}"
    fi
}

# Enable the service to start on boot function
enable_service() {
    echo -e "${NC}Enabling log_simulator daemon to start on boot${NC}"
    sudo systemctl enable log_simulator
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to enable daemon on boot${NC}" 1>&2
        exit 1
    fi
}

# Disable the service to start on boot function
disable_service() {
    echo -e "${NC}Disabling log_simulator daemon to start on boot${NC}"
    sudo systemctl disable log_simulator
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to disable daemon on boot${NC}" 1>&2
        exit 1
    else
        echo -e "${GREEN}Successfully disabled daemon on boot${NC}"
    fi
}

# Check if the Python script directory exists function
check_install_directory() {
    if [ -d "$destination_path_to_log_simulator" ]; then
        echo -e "${GREEN}The log simulator directory found${NC}" 1>&2
        return 0
    else
        echo -e "${RED}The log simulator directory not found${NC}" 1>&2
        return 1
    fi
}

# Remove the Python script directory if it exists function. Use the check_install_directory() function
remove_install_directory() {
    if check_install_directory ; then
        echo -e "${NC}Removing $destination_path_to_log_simulator${NC}"
        sudo rm -r "$destination_path_to_log_simulator"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to remove Python script directory${NC}" 1>&2
            exit 1
        else
            echo -e "${GREEN}Successfully removed Python script directory${NC}"
        fi
    fi
}

# main function
main() {
    parse_arguments "$@"
    check_root

    # If uninstall = false, install the script
    if ! $uninstall; then
        echo -e "${BLUE}Installing Linux Log Generator${NC}"
        check_apt_get
        check_python
        make_script_executable
        copy_script_files
        if $install_as_service; then
            copy_service_files
            reload_systemd
            start_service
            enable_service
        fi
        echo -e "${GREEN}Install Complete${NC}"
    else
        # Check if the service file exists
        if [ -f "$destination_path_to_service_file" ]; then
            stop_service
            disable_service
            remove_service_file
        fi
        remove_install_directory
        echo -e "${GREEN}Uninstall Complete${NC}"
    fi
    echo -e "${BLUE}$divider${NC}"
}

# Run main function
main "$@"
