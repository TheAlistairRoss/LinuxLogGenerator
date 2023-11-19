#!/bin/bash
set -e
set -u

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

title="Linux Log Generator - Installer"
author="theAlistairRoss"
len=${#title}
divider=$(printf '%*s' "$len" '' | tr ' ' '-')

echo -e "${BLUE}$title${NC}"
echo -e "Author: ${BLUE}@theAlistairRoss${NC}"
echo -e "${BLUE}$divider${NC}"

# Set variables
script_name="log_simulator.py"
source_path="../src"
source_path_to_python_script="$source_path/$script_name"
source_path_to_service_file="log_simulator.service"
destination_path_to_log_simulator="/opt/log_simulator"
destination_path_to_service_file="/etc/systemd/system/log_simulator.service"
required_minimum_python_version="3.8"

# Set default values
uninstall=false
install_as_service=false
unattended=false

# Functions
# Parse arguments
parse_arguments() {
    while getopts ":ishu" opt; do
        case ${opt} in
            i ) 
                install_as_service=true
                ;;
            s ) 
                unattended=true
                ;;
            h ) 
                display_help
                ;;
            u ) 
                uninstall=true
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
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}This script must be run as root${NC}" 1>&2
       exit 1
    fi
}

# Display help message
display_help() {
    echo
    echo "This script installs the log simulator on a Linux machine. It can be run in unattended mode or interactive mode and can install the script as a service to run on boot. It also includes the option to uninstall the script as a service."
    echo "Usage: $0 [option...]" >&2
    echo
    echo "   -i, --install_as_service   Install the script as a service (default = false)"
    echo "   -s, --silent               Run the script in silent (unattended) mode"
    echo "   -h, --help                 Display this help message"
    echo "   -u, --uninstall            Uninstall the script as a service"
    echo
    exit 1
}

# Check if apt-get is installed function
check_apt_get() {
    echo "Checking apt-get"
    if ! command -v apt-get &> /dev/null
    then
        echo -e "${RED}This script requires apt-get but it's not installed. Are you sure you're running a Debian-based distribution?${NC}" 1>&2
        exit 1
    fi
}

# Function to check if a string is a valid floating point number
is_float() {
    local num=$1
    [[ $num =~ ^[+-]?[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?$ ]]
    return $?
}

# Check if Python is installed function and if it is the correct minimum version
check_python() {
    echo "Checking Python"
    if ! command -v python3 &> /dev/null
    then
        echo -e "${RED}Python3 is not installed${NC}" 1>&2
        return 0
    else
        python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        if ! is_float "$python_version"; then
            echo "Error: python_version is not a valid floating point number"
            exit 1
        fi
        if ! is_float "$required_minimum_python_version"; then
            echo "Error: required_minimum_python_version is not a valid floating point number"
            exit 1
        fi
        if [ $(echo "$python_version >= $required_minimum_python_version" | bc -l) -ne 1 ]; then
            echo -e "${RED}Python3 version $required_minimum_python_version or greater is required${NC}" 1>&2
            return 0
        else
            echo -e "${GREEN}Python3 version $python_version installed${NC}"
            return 1
        fi
    fi
}

# Install Python function
install_python() {
    echo "Checking Python"
    if check_python; then
        if $unattended; then
            # Update package lists
            sudo apt-get update -y
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to update package lists${NC}" 1>&2
                exit 1
            else
                echo -e "${GREEN}Updated package lists${NC}"
            fi

            # Install Python3 and pip3 without asking for confirmation
            echo "Installing python3"
            sudo apt-get install -y python3 python3-pip
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to install Python3 and pip3${NC}" 1>&2
                exit 1
            else
                echo -e "${GREEN}Python3 installed${NC}"
            fi
        else
            # Update package lists
            sudo apt-get update
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to update package lists${NC}" 1>&2
                exit 1
            else
                echo -e "${GREEN}Updated package lists${NC}"
            fi

            # Ask for confirmation before installing Python3 and pip3
            read -p "Python3 is not installed or the version is less than the required. Would you like to install it now? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo apt-get install -y python3 python3-pip
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Failed to install Python3 and pip3${NC}" 1>&2
                    exit 1
                else
                    echo -e "${GREEN}Python3 installed${NC}"
                fi
            fi
        fi
    else
        echo -e "${GREEN}Python already installed${NC}"
    fi
}

# Make the Python script executable function
make_script_executable() {
    chmod +x "$source_path_to_python_script"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to make Python script executable${NC}" 1>&2
        exit 1
    fi
}

# Copy the Python script files function
copy_files() {
    if ! cmp -s "$source_path_to_python_script" "$destination_path_to_log_simulator"; then
        echo -e "${NC}Copying contents of $source_path_to_python_script to $destination_path_to_log_simulator${NC}"
        
        # Create the directory if it does not exist
        if [ ! -d "$destination_path_to_log_simulator" ]; then
            sudo mkdir -p "$destination_path_to_log_simulator"
        fi

        sudo cp "$source_path_to_python_script" "$destination_path_to_log_simulator"        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to copy the files${NC}" 1>&2
            exit 1
        else
            echo -e "${GREEN}Successfully copied the files${NC}"
        fi
    fi
}

# Copy the service file function
copy_service_file() {
    echo -e "${NC}Copying $source_path_to_service_file to $destination_path_to_service_file${NC}"
    sudo cp "$source_path_to_service_file" "$destination_path_to_service_file"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to copy service file${NC}" 1>&2
        exit 1
    else
        echo -e "${GREEN}Successfully copied service file${NC}"
    fi
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
        install_python
        make_script_executable
        copy_files
        if $install_as_service; then
            copy_service_file
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
main
