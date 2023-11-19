#!/bin/bash

# Set variables

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

title="Linux Log Generator - Downloader"
author="theAlistairRoss"
len=${#title}
divider=$(printf '%*s' "$len" '' | tr ' ' '-')

# download_url
download_url="https://github.com/TheAlistairRoss/LinuxLogGenerator/raw/main/package/LinuxLogGenerator.zip"

# Title
echo -e "${BLUE}$title${NC}"
echo -e "Author: ${BLUE}@theAlistairRoss${NC}"
echo -e "${BLUE}$divider${NC}"

# Download the zip file
echo -e "${YELLOW}Downloading the zip file...${NC}" 1>&2
if ! wget $download_url; then
    echo -e "${RED}Failed to download the zip file${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}Download successful${NC}" 1>&2
fi

# Unzip the downloaded file
echo -e "${YELLOW}Unzipping the downloaded file...${NC}" 1>&2
if ! unzip LinuxLogGenerator.zip; then
    echo -e "${RED}Failed to unzip the file${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}Unzip successful${NC}" 1>&2
fi

# Remove the zip file
echo -e "${YELLOW}Removing the zip file...${NC}" 1>&2
if ! rm LinuxLogGenerator.zip; then
    echo -e "${RED}Failed to remove the zip file${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}Zip file removed${NC}" 1>&2
fi

# Change into the install directory
cd install

# Make the install.sh script executable
echo -e "${YELLOW}Making the install.sh script executable...${NC}" 1>&2
if ! chmod +x install.sh; then
    echo -e "${RED}Failed to make the install.sh script executable${NC}" 1>&2
    exit 1
else
    echo -e "${GREEN}install.sh script is now executable${NC}" 1>&2
fi

# Check if the user is root, if they are, run the script. Provide messages for both states.
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}This script must be run as root${NC}" 1>&2
   echo -e "${YELLOW}Run the 'sudo ./install.sh' to run just the installer.${NC}" 1>&2
   exit 1
else
    echo -e "${GREEN}Running Install Script${NC}" 1>&2
    sudo ./install.sh
fi