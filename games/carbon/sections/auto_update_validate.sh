#!/bin/bash

################################
# STEAMCMD DOWNLOAD GAME FILES #
################################
# We need to source this file first before we do any auto update or validation logic

if [ -f /helpers/steamcmd.sh ]; then
  Debug "/helpers/steamcmd.sh exists and is found!"
  # Directly run the script without chmod
  source /helpers/steamcmd.sh
else
  Error "/helpers/steamcmd.sh does not exist or cannot be found." "1"
fi

##############################################
# SET DEFAULT DOWNLOAD METHOD IF NOT DEFINED #
##############################################

if [ -z "${DOWNLOAD_METHOD}" ]; then
    Warn "DOWNLOAD_METHOD variable not found. Update your egg at https://github.com/SturdyStubs/AIO.Egg. Defaulting to SteamCMD..."
    DOWNLOAD_METHOD="SteamCMD"
else
    echo "DOWNLOAD_METHOD is set to '${DOWNLOAD_METHOD}'."
fi

########################################
# DOWNLOAD AND CLEANUP DOWNLOAD METHOD #
########################################

# Define the DepotDownloader version check URL
GITHUB_API_URL="https://api.github.com/repos/SteamRE/DepotDownloader/releases/latest"

# Fetch the latest version number from GitHub
LATEST_VERSION=$(curl -s "${GITHUB_API_URL}" | grep -oP '"tag_name": "\K(.*)(?=")')
LATEST_VERSION=$(echo "$LATEST_VERSION" | xargs)  # Trim any extra whitespace

# Check the installed version by running DepotDownloader with a version flag
if [ -f /home/container/DepotDownloader ]; then
    CURRENT_VERSION=$(/home/container/DepotDownloader --version 2>&1 | grep -oP '\d+\.\d+\.\d+')
    CURRENT_VERSION=$(echo "$CURRENT_VERSION" | xargs)  # Trim any extra whitespace
else
    CURRENT_VERSION="none"  # Indicator for a fresh installation
fi

# Print versions for debugging
echo "Detected Current Version: $CURRENT_VERSION"
echo "Latest Version from GitHub: $LATEST_VERSION"

DOWNLOAD_URL="https://github.com/SteamRE/DepotDownloader/releases/download/${LATEST_VERSION}/DepotDownloader-linux-x64.zip"

if [[ "${DOWNLOAD_METHOD}" == "Depot Downloader" ]]; then
    # Check if ./DepotDownloader already exists
    if [ -f /home/container/DepotDownloader ]; then
        echo "DepotDownloader found."

        # Check if the current version matches the latest version
        if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
            echo "DepotDownloader is up-to-date. No installation needed."
        else
            echo "DepotDownloader is outdated. Updating to version ${LATEST_VERSION}..."
            # Proceed with download and installation of the new version
            cd /tmp
            curl -sSL -o DepotDownloader.zip "$DOWNLOAD_URL"
            unzip -o DepotDownloader.zip -d /home/container
            rm -rf /tmp/*
            chmod +x /home/container/DepotDownloader
            echo "DepotDownloader updated successfully to version ${LATEST_VERSION}."
            exit 0
        fi
    else
        echo "DepotDownloader not found. Installing DepotDownloader..."
        # Install the latest version if it doesn't exist
        cd /tmp
        curl -sSL -o DepotDownloader.zip "$DOWNLOAD_URL"
        unzip DepotDownloader.zip -d /home/container
        rm -rf /tmp/*
        chmod +x /home/container/DepotDownloader
        echo "DepotDownloader installation completed successfully."
        exit 0
    fi
fi

# SteamCMD is required for the server to boot up, check that its installed
if [ -d /home/container/steamcmd ]; then
    echo "SteamCMD found. Skipping installation."
else
    mkdir -p /home/container/steamcmd
    curl -sSL -o steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    tar -xzvf steamcmd.tar.gz -C /home/container/steamcmd
    mkdir -p /home/containersteamapps # Fix steamcmd disk write error when this folder is missing
    # SteamCMD fails otherwise for some reason, even running as root.
    # This is changed at the end of the install process anyways.
    
    ## set up 32 bit libraries
    mkdir -p /home/container/.steam/sdk32
    cp -v linux32/steamclient.so ../.steam/sdk32/steamclient.so
    ## set up 64 bit libraries
    mkdir -p /home/container/.steam/sdk64
    cp -v linux64/steamclient.so ../.steam/sdk64/steamclient.so
    Warn "SteamCMD installation completed successfully, restarting server to apply changes..."
    exit 1
fi

# If RustDedicated does not have the permissions, give it permissions
if [ "$(stat -c "%a" /home/container/RustDedicated)" -ne 755 ]; then
    chmod +x /home/container/RustDedicated
fi

#######################################################
# CLEAN RUSTDEDICATED_DATA FOLDER OF OXIDE EXTENSIONS #
#######################################################

if [ -f /helpers/clean_rustdedicated.sh ]; then
  Debug "/helpers/clean_rustdedicated.sh exists and is found!"
  # Directly run the script without chmod
  source /helpers/clean_rustdedicated.sh
else
  Error "/helpers/clean_rustdedicated.sh does not exist or cannot be found." "1"
fi

###################################
# HANDLE AUTO UPDATE / VALIDATION #
###################################

source /helpers/messages.sh

Debug "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
Debug "Inside /sections/auto_update_validate.sh file!"

echo "Handling Auto Update and Validation..."

# If the switch is occurring from oxide to rust, we want to validate all the steam files first before
# downloading carbon every time. Force validation. This will remove all references to oxide in the files.
if [[ "${DOWNLOAD_METHOD}" == "SteamCMD" ]]; then
    if [[ "${CARBONSWITCH}" == "TRUE" ]]; then
        Info "Carbon Switch Detected!"
        Info "Forcing validation of game server..."
        # Go to this function
        SteamCMD_Validate
        Clean_RustDedicated
    elif [[ "${FRAMEWORK}" == "*vanilla*" ]]; then
        Info "Vanilla or Vanilla-Staging framework detected!"
        Info "Forcing validation of game server..."
        SteamCMD_Validate
        Clean_RustDedicated
    elif [[ "${AUTO_UPDATE}" == "1" ]]; then
        # Else, we're going to handle the auto update. If the auto update is set to true, or is null or doesn't exist
        # Check if we're going to validate after updating
        if [ "${VALIDATE}" == "1" ]; then
            # If VALIDATE set to true, validate game server via this function
            SteamCMD_Validate
        else
            # Else don't validate via this function
            SteamCMD_No_Validation
        fi
    fi
fi

if [[ "${DOWNLOAD_METHOD}" == "Depot Downloader" ]]; then
    if [[ "${CARBONSWITCH}" == "TRUE" ]]; then
        Info "Carbon Switch Detected!"
        Info "Forcing validation of game server..."
        # Go to this function
        DepotDownloader_Validate
        Clean_RustDedicated
    elif [[ "${FRAMEWORK}" == "*vanilla*" ]]; then
        Info "Vanilla or Vanilla-Staging framework detected!"
        Info "Forcing validation of game server..."
        DepotDownloader_Validate
        Clean_RustDedicated
    elif [[ "${AUTO_UPDATE}" == "1" ]]; then
        # Else, we're going to handle the auto update. If the auto update is set to true, or is null or doesn't exist
        # Check if we're going to validate after updating
        if [ "${VALIDATE}" == "1" ]; then
            # If VALIDATE set to true, validate game server via this function
            DepotDownloader_Validate
        else
            # Else don't validate via this function
            DepotDownloader_No_Validation
        fi
    fi
fi
