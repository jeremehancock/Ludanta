#!/bin/bash

# Ludanta: Now Playing on Plex/Jellyfin
# Display what is currently playing on your Plex and/or Jellyfin servers on the command line.
#
# Developed by Jereme Hancock
# https://github.com/jeremehancock/Ludanta
#
# MIT License
#
# Copyright (c) 2024 Jereme Hancock
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

########################################################################################################
######################################### Configuration ################################################
########################################################################################################

# Plex Configuration
PLEX_ENABLED=true                               # Set to false to disable Plex checking
PLEX_URL="http://localhost:32400"
PLEX_TOKEN=""

# Jellyfin Configuration
JELLYFIN_ENABLED=true                           # Set to false to disable Jellyfin checking
JELLYFIN_URL="http://localhost:8096"
JELLYFIN_API_KEY=""

########################################################################################################
################################### DO NOT EDIT ANYTHING BELOW #########################################
########################################################################################################

VERSION="1.0.3"

show_version() {
    echo "Ludanta v${VERSION}"
    check_version
}

check_version() {
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required for version checking"
        return 1
    fi

    local remote_version
    remote_version=$(curl -s -H "Cache-Control: no-cache" https://raw.githubusercontent.com/jeremehancock/Ludanta/refs/heads/main/ludanta.sh | grep "^VERSION=" | cut -d'"' -f2)
    
    if [[ -z "$remote_version" ]]; then
        echo "Error: Could not fetch remote version"
        return 1
    fi

    if [[ "$remote_version" > "$VERSION" ]]; then
        echo "Update available: v$VERSION → v$remote_version"
        echo "Use -u to update to the latest version"
        return 0
    fi
}

update_script() {
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required for updating"
        return 1
    fi

    local remote_version
    remote_version=$(curl -s -H "Cache-Control: no-cache" https://raw.githubusercontent.com/jeremehancock/Ludanta/refs/heads/main/ludanta.sh | grep "^VERSION=" | cut -d'"' -f2)
    
    if [[ -z "$remote_version" ]]; then
        echo "Error: Could not fetch remote version"
        return 1
    fi

    if [[ "$remote_version" == "$VERSION" ]]; then
        echo "No updates available. You are running the latest version (v${VERSION})."
        return 0
    fi

    echo "Update available: v$VERSION → v$remote_version"
    
    local backup_dir="backups"
    mkdir -p "$backup_dir"

    local script_name=$(basename "$0")
    local backup_file="${backup_dir}/${script_name}.v${VERSION}.backup"
    cp "$0" "$backup_file"
    
    echo -n "Do you want to proceed with the update? [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Update cancelled."
        return 0
    fi
    
    if curl -H "Cache-Control: no-cache" -o "$script_name" -L https://raw.githubusercontent.com/jeremehancock/Ludanta/main/ludanta.sh; then
        local last_backup=$(ls -t "$backup_dir"/*.backup | head -n 1)
        
        if [[ -n "$last_backup" ]]; then
            # Restore configuration from backup
            local old_plex_enabled=$(grep "^PLEX_ENABLED=" "$last_backup" | cut -d'=' -f2)
            local old_plex_url=$(grep "^PLEX_URL=" "$last_backup" | cut -d'"' -f2)
            local old_plex_token=$(grep "^PLEX_TOKEN=" "$last_backup" | cut -d'"' -f2)
            local old_jellyfin_enabled=$(grep "^JELLYFIN_ENABLED=" "$last_backup" | cut -d'=' -f2)
            local old_jellyfin_url=$(grep "^JELLYFIN_URL=" "$last_backup" | cut -d'"' -f2)
            local old_jellyfin_api_key=$(grep "^JELLYFIN_API_KEY=" "$last_backup" | cut -d'"' -f2)
            
            if [[ -n "$old_plex_enabled" ]]; then
                sed -i "s|^PLEX_ENABLED=.*|PLEX_ENABLED=$old_plex_enabled|" "$script_name"
            fi
            if [[ -n "$old_plex_url" ]]; then
                sed -i "s|^PLEX_URL=.*|PLEX_URL=\"$old_plex_url\"|" "$script_name"
            fi
            if [[ -n "$old_plex_token" ]]; then
                sed -i "s|^PLEX_TOKEN=.*|PLEX_TOKEN=\"$old_plex_token\"|" "$script_name"
            fi
            if [[ -n "$old_jellyfin_enabled" ]]; then
                sed -i "s|^JELLYFIN_ENABLED=.*|JELLYFIN_ENABLED=$old_jellyfin_enabled|" "$script_name"
            fi
            if [[ -n "$old_jellyfin_url" ]]; then
                sed -i "s|^JELLYFIN_URL=.*|JELLYFIN_URL=\"$old_jellyfin_url\"|" "$script_name"
            fi
            if [[ -n "$old_jellyfin_api_key" ]]; then
                sed -i "s|^JELLYFIN_API_KEY=.*|JELLYFIN_API_KEY=\"$old_jellyfin_api_key\"|" "$script_name"
            fi
        fi
        
        chmod +x "$script_name"
        echo "Successfully updated script"
        echo "Previous version backed up to $backup_file"
        
        exit 0
    else
        echo "Update failed"
        mv "$backup_file" "$script_name"
        return 1
    fi
}

check_dependencies() {
    local deps=("curl" "xmlstarlet" "jq" "tput")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        printf "Missing required dependencies: %s\n" "${missing[*]}"
        printf "Please install them and try again.\n"
        exit 1
    fi
}

check_terminal_support() {
    if command -v tput >/dev/null 2>&1; then
        if tput setaf 1 >/dev/null 2>&1; then
            # Terminal supports colors
            blue_color=$(tput setaf 4)
            orange_color=$(tput setaf 3)  # Using yellow as fallback for orange
            green_color=$(tput setaf 2)
        else
            blue_color=""
            orange_color=""
            green_color=""
        fi
        
        # Check for italic support
        if tput sitm >/dev/null 2>&1; then
            italic_start=$(tput sitm)
            italic_end=$(tput ritm)
        else
            # Fallback to dim if italic not supported
            if tput dim >/dev/null 2>&1; then
                italic_start=$(tput dim)
                italic_end=$(tput sgr0)
            else
                italic_start=""
                italic_end=""
            fi
        fi
        reset=$(tput sgr0)
    else
        # No tput support, use basic ANSI codes
        blue_color="\e[34m"
        orange_color="\e[33m"
        green_color="\e[32m"
        italic_start="\e[3m"
        italic_end="\e[23m"
        reset="\e[0m"
    fi
}

safe_echo() {
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        # macOS
        /bin/echo "$@"
    else
        # Linux and others
        echo -e "$@"
    fi
}

urlencode() {
    local string="$1"
    echo -n "$string" | curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "" | cut -c 3-
}

decode_html_entities() {
    echo "$1" | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'"'"'/g' | sed 's/&$//'
}

check_plex() {
    if [ "$PLEX_ENABLED" = true ] && [ -n "$PLEX_TOKEN" ]; then
        local plex_xml
        plex_xml=$(curl -s "${PLEX_URL}/status/sessions?X-Plex-Token=${PLEX_TOKEN}")
        
        if [ -n "$plex_xml" ]; then
            local currently_playing
            currently_playing=$(printf '%s' "$plex_xml" | LC_ALL=C xmlstarlet sel -t \
                -m "//MediaContainer/Video | //MediaContainer/Track" \
                -v "concat(
                    @grandparentTitle,
                    substring(' - ', 1, number(string-length(@grandparentTitle) > 0) * 3),
                    @title,
                    '...................',
                    ./User/@title
                )" \
                -m ".//TranscodeSession" \
                -i "@videoDecision='transcode' or @audioDecision='transcode'" \
                    -o " •" \
                -b \
                -n)
            
            if [ -n "$currently_playing" ]; then
                safe_echo ""
                safe_echo "Now Playing on ${HOSTNAME^} (${italic_start}${orange_color}Plex${reset}):${reset}"
                # Decode HTML entities before displaying
                while IFS= read -r line; do
                    if [ -n "$line" ]; then
                        decoded_line=$(decode_html_entities "$line")
                        # Remove any empty dots-only lines
                        if [[ "$decoded_line" != *".................."* || "$decoded_line" =~ [^\.] ]]; then
                            safe_echo "${green_color}${decoded_line}${reset}"
                        fi
                    fi
                done <<< "$currently_playing"
            fi
        fi
    fi
}

check_jellyfin() {
    if [ "$JELLYFIN_ENABLED" = true ] && [ -n "$JELLYFIN_API_KEY" ]; then
        local currently_playing
        currently_playing=$(curl -s "${JELLYFIN_URL}/Sessions?api_key=${JELLYFIN_API_KEY}" | \
            jq -r '.[] | select(.NowPlayingItem != null) | 
            if .NowPlayingItem.Type == "Audio" then
                if .NowPlayingItem.AlbumArtist != null and .NowPlayingItem.AlbumArtist != "" then
                    "\(.NowPlayingItem.AlbumArtist) - \(.NowPlayingItem.Name)"
                else
                    "\(.NowPlayingItem.Name)"
                end
            elif .NowPlayingItem.SeriesName != null and .NowPlayingItem.SeriesName != "" then
                "\(.NowPlayingItem.SeriesName) - \(.NowPlayingItem.Name)"
            else
                "\(.NowPlayingItem.Name)"
            end + " ...................\(.UserName) \(.PlayState.PlayMethod)"')
        
        if [ -n "$currently_playing" ]; then
            currently_playing=$(printf '%s' "$currently_playing" | sed 's/\bTranscode\b/•/')
            currently_playing=$(printf '%s' "$currently_playing" | sed 's/\bDirectPlay\b//')
            
            safe_echo ""
            safe_echo "Now Playing on ${HOSTNAME^} (${italic_start}${blue_color}Jellyfin${reset}):${reset}"
            safe_echo "${green_color}${currently_playing}${reset}"
        fi
    fi
}

main() {
    check_dependencies
    
    while getopts "vu" opt; do
        case ${opt} in
            v )
                show_version
                exit 0
                ;;
            u )
                update_script
                exit 0
                ;;
            \? )
                echo "Invalid Option: -$OPTARG" 1>&2
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))
    
    check_terminal_support
    check_plex
    check_jellyfin
    
    # Add a final newline if anything was displayed
    if { [ "$JELLYFIN_ENABLED" = true ] && [ -n "$JELLYFIN_API_KEY" ]; } || \
       { [ "$PLEX_ENABLED" = true ] && [ -n "$PLEX_TOKEN" ]; }; then
        safe_echo ""
    fi
}

main "$@"
