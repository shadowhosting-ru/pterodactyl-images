#!/bin/bash

################################
# STEAMCMD DOWNLOAD GAME FILES #
################################

source /helpers/messages.sh

Debug "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
Debug "Inside /helpers/steamcmd.sh file!"

Info "Sourcing SteamCMD Script..."

# SteamCMD is required for the server to boot up, check that its installed
if [ -d /home/container/steamcmd ]; then
    echo "SteamCMD found. Skipping installation."
else
    mkdir -p /home/container/steamcmd
    curl -sSL -o steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    tar -xzvf steamcmd.tar.gz -C /home/container/steamcmd
    mkdir -p /home/container/steamapps # Fix steamcmd disk write error when this folder is missing
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
# We need to delete the steamapps directory in order to prevent the following error:
# Error! App '258550' state is 0x486 after update job.
# Ref: https://www.reddit.com/r/playark/comments/3smnog/error_app_376030_state_is_0x486_after_update_job/
function Delete_SteamApps_Directory() {
    Debug "Deleting SteamApps Folder as a precaution..."
    rm -rf /home/container/steamapps
}

# Validate when downloading
function SteamCMD_Validate() {
	Debug "Inside Function: SteamCMD_Validate()"

    if [[ "${FRAMEWORK}" == *"aux1"* ]]; then
        Delete_SteamApps_Directory
        Info "Downloading Aux1 Files - Validation On!"
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 -beta aux01 validate +quit
    elif [[ "${FRAMEWORK}" == *"aux2"* ]]; then
        Delete_SteamApps_Directory
        Info "Downloading Aux2 Files - Validation On!"
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 -beta aux02 validate +quit
    elif [[ "${FRAMEWORK}" == *"staging"* ]]; then
        Delete_SteamApps_Directory
        Info "Downloading Staging Files - Validation On!"
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 -beta staging validate +quit
    else
        Delete_SteamApps_Directory
        Info "Downloading Default Files - Validation On!"
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 validate +quit
    fi
}

# Don't validate while downloading
function SteamCMD_No_Validation() {
	Debug "Inside Function: SteamCMD_No_Validation()"

    if [[ "${FRAMEWORK}" == *"aux1"* ]]; then
        Info "Downloading Aux1 Files - Validation Off!"
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 -beta aux01 +quit
    elif [[ "${FRAMEWORK}" == *"aux2"* ]]; then
        Info "Downloading Aux2 Files - Validation Off!"
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 -beta aux02 +quit
    elif [[ "${FRAMEWORK}" == *"staging"* ]]; then
        Info "Downloading Staging Files - Validation Off!"
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 -beta staging +quit
    else
        Info "Downloading Default Files - Validation Off!"
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 +quit
    fi
}
