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

VERSION="1.0.9"
VERBOSE=false

get_plex_server_name() {
    if [ "$PLEX_ENABLED" = true ] && [ -n "$PLEX_TOKEN" ]; then
        local server_info
        server_info=$(curl -s "${PLEX_URL}/servers?X-Plex-Token=${PLEX_TOKEN}")
        if [ -n "$server_info" ]; then
            echo "$server_info" | xmlstarlet sel -t -v "/MediaContainer/Server/@name" 2>/dev/null || echo "Plex Server"
        else
            echo "Plex Server"
        fi
    fi
}

get_jellyfin_server_name() {
    if [ "$JELLYFIN_ENABLED" = true ] && [ -n "$JELLYFIN_API_KEY" ]; then
        local server_info
        server_info=$(curl -s "${JELLYFIN_URL}/System/Info?api_key=${JELLYFIN_API_KEY}")
        if [ -n "$server_info" ]; then
            echo "$server_info" | jq -r '.ServerName // "Jellyfin Server"'
        else
            echo "Jellyfin Server"
        fi
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
        
        # Check for italic support using a more compatible approach
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
        # No tput support, use basic ANSI codes with printf for better compatibility
        blue_color=$(printf '\033[34m')
        orange_color=$(printf '\033[33m')
        green_color=$(printf '\033[32m')
        italic_start=$(printf '\033[3m')
        italic_end=$(printf '\033[23m')
        reset=$(printf '\033[0m')
    fi
}

safe_echo() {
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        # macOS: Use printf for better compatibility
        printf "%b\n" "$*"
    else
        # Linux and others
        echo -e "$@"
    fi
}

urlencode() {
    local string="$1"
    printf '%s' "$string" | curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "" | cut -c 3-
}

decode_html_entities() {
    printf '%s' "$1" | sed -e 's/&amp;/\&/g' \
                          -e 's/&lt;/</g' \
                          -e 's/&gt;/>/g' \
                          -e 's/&quot;/"/g' \
                          -e 's/&#39;/'"'"'/g' \
                          -e 's/&$//'
}

check_version() {
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required for version checking"
        return 1
    fi

    # Use grep -a to treat file as text for macOS compatibility
    local remote_version
    remote_version=$(curl -s -H "Cache-Control: no-cache" https://raw.githubusercontent.com/jeremehancock/Ludanta/refs/heads/main/ludanta.sh | grep -a "^VERSION=" | cut -d'"' -f2)
    
    if [ -z "$remote_version" ]; then
        echo "Error: Could not fetch remote version"
        return 1
    fi

    # Only show update available if remote version is newer
    if printf '%s\n' "$remote_version" "$VERSION" | sort -V | tail -n1 | grep -q "^$remote_version" && [ "$remote_version" != "$VERSION" ]; then
        printf "Update available: v%s → v%s\n" "$VERSION" "$remote_version"
        echo "Use -u to update to the latest version"
        return 0
    fi
}

show_version() {
    echo "Ludanta v${VERSION}"
    check_version
}

update_script() {
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required for updating"
        return 1
    fi

    # Use grep -a to treat file as text for macOS compatibility
    local remote_version
    remote_version=$(curl -s -H "Cache-Control: no-cache" https://raw.githubusercontent.com/jeremehancock/Ludanta/refs/heads/main/ludanta.sh | grep -a "^VERSION=" | cut -d'"' -f2)
    
    if [ -z "$remote_version" ]; then
        echo "Error: Could not fetch remote version"
        return 1
    fi

    if [ "$remote_version" = "$VERSION" ]; then
        echo "No updates available. You are running the latest version (v${VERSION})."
        return 0
    fi

    printf "Update available: v%s → v%s\n" "$VERSION" "$remote_version"
    
    local backup_dir="backups"
    mkdir -p "$backup_dir"

    local script_name=$(basename "$0")
    local backup_file="${backup_dir}/${script_name}.v${VERSION}.backup"
    cp "$0" "$backup_file"
    
    printf "Do you want to proceed with the update? [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Update cancelled."
        return 0
    fi
    
    if curl -H "Cache-Control: no-cache" -o "$script_name" -L https://raw.githubusercontent.com/jeremehancock/Ludanta/main/ludanta.sh; then
        local last_backup=$(ls -t "$backup_dir"/*.backup 2>/dev/null | head -n 1)
        
        if [ -n "$last_backup" ]; then
            # Restore configuration from backup using more compatible grep patterns
            local old_plex_enabled=$(grep "^PLEX_ENABLED=" "$last_backup" | cut -d'=' -f2)
            local old_plex_url=$(grep "^PLEX_URL=" "$last_backup" | cut -d'"' -f2)
            local old_plex_token=$(grep "^PLEX_TOKEN=" "$last_backup" | cut -d'"' -f2)
            local old_jellyfin_enabled=$(grep "^JELLYFIN_ENABLED=" "$last_backup" | cut -d'=' -f2)
            local old_jellyfin_url=$(grep "^JELLYFIN_URL=" "$last_backup" | cut -d'"' -f2)
            local old_jellyfin_api_key=$(grep "^JELLYFIN_API_KEY=" "$last_backup" | cut -d'"' -f2)
            
            # Use more compatible sed syntax for macOS
            if [ -n "$old_plex_enabled" ]; then
                sed -i.bak "s|^PLEX_ENABLED=.*|PLEX_ENABLED=$old_plex_enabled|" "$script_name"
            fi
            if [ -n "$old_plex_url" ]; then
                sed -i.bak "s|^PLEX_URL=.*|PLEX_URL=\"$old_plex_url\"|" "$script_name"
            fi
            if [ -n "$old_plex_token" ]; then
                sed -i.bak "s|^PLEX_TOKEN=.*|PLEX_TOKEN=\"$old_plex_token\"|" "$script_name"
            fi
            if [ -n "$old_jellyfin_enabled" ]; then
                sed -i.bak "s|^JELLYFIN_ENABLED=.*|JELLYFIN_ENABLED=$old_jellyfin_enabled|" "$script_name"
            fi
            if [ -n "$old_jellyfin_url" ]; then
                sed -i.bak "s|^JELLYFIN_URL=.*|JELLYFIN_URL=\"$old_jellyfin_url\"|" "$script_name"
            fi
            if [ -n "$old_jellyfin_api_key" ]; then
                sed -i.bak "s|^JELLYFIN_API_KEY=.*|JELLYFIN_API_KEY=\"$old_jellyfin_api_key\"|" "$script_name"
            fi
            
            # Clean up backup files created by sed on macOS
            rm -f "$script_name.bak"
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

# Here's the modified check_plex function. The main change is in the xmlstarlet formatting string
# to add additional newlines between sessions.

check_plex() {
    if [ "$PLEX_ENABLED" = true ] && [ -n "$PLEX_TOKEN" ]; then
        local plex_xml
        plex_xml=$(curl -s "${PLEX_URL}/status/sessions?X-Plex-Token=${PLEX_TOKEN}")
        
        if [ -n "$plex_xml" ]; then
            local server_name
            server_name=$(get_plex_server_name)
            local currently_playing
            if [ "$VERBOSE" = true ]; then
                # Verbose output remains the same...
                currently_playing=$(printf '%s' "$plex_xml" | LC_ALL=C xmlstarlet sel -t \
                    -m "//MediaContainer/Video | //MediaContainer/Track" \
                    -v "concat(
                        @grandparentTitle,
                        substring(' - ', 1, number(string-length(@grandparentTitle) > 0) * 3),
                        @title,
                        '...................',
                        ./User/@title
                    )" \
                    -n \
                    -v "concat(
                        '    Media Info: ',
                        substring(
                            concat(
                                substring('Live TV', 1, number(not(number(@duration) > 0)) * 7),
                                substring(concat(format-number(@duration div 1000 div 60, '0'), ' min'), 1, number(@duration > 0) * 20)
                            ),
                            1
                        )
                    )" \
                    -n \
                    -m ".//Media" \
                    -v "concat(
                        '    Media Info: Container: ', 
                        @container,
                        ', Audio Channels: ',
                        @audioChannels,
                        ', Resolution: ',
                        @videoResolution,
                        'p'
                    )" \
                    -n \
                    -n \
                    -b \
                    -m ".//TranscodeSession" \
                    -v "concat(
                        '    Transcoding: ',
                        'Video: ', @videoDecision, 
                        ', Audio: ', @audioDecision,
                        ', Progress: ',
                        substring(
                            concat(
                                substring('Live', 1, number(not(number(@progress) > -1)) * 4),
                                substring(concat(format-number(@progress, '0.00'), '%'), 1, number(@progress > -1) * 10)
                            ),
                            1
                        )
                    )" \
                    -n \
                    -b \
                    -m ".//Stream[@streamType='1']" \
                    -v "concat(
                        '    Video Stream: ',
                        'Codec: ', @codec,
                        ', Bitrate: ', @bitrate div 1000, ' Mbps',
                        ', Framerate: ', format-number(@frameRate, '0.00'),
                        ' (', @width, 'x', @height, ')'
                    )" \
                    -n \
                    -b \
                    -m ".//Stream[@streamType='2']" \
                    -v "concat(
                        '    Audio Stream: ',
                        'Codec: ', @codec,
                        ', Channels: ', @channels,
                        ', Language: ', @language,
                        ', Bitrate: ', @bitrate div 1000, ' Mbps'
                    )" \
                    -n \
                    -b \
                    -m ".//Player" \
                    -v "concat(
                        '    Player: ',
                        @product, ' on ', @platform,
                        ', State: ', @state,
                        ', Stream Origin: ', 
                        substring('RemoteLocal', 1 + number(@local = '1') * 6, 6)
                    )" \
                    -n \
                    -n \
                    -b)
            else
                # Modified non-verbose output to properly handle both transcodes and line breaks
                currently_playing=$(printf '%s' "$plex_xml" | LC_ALL=C xmlstarlet sel -t \
                    -m "//MediaContainer/Video | //MediaContainer/Track" \
                    -v "concat(
                        @grandparentTitle,
                        substring(' - ', 1, number(string-length(@grandparentTitle) > 0) * 3),
                        @title,
                        '...................',
                        ./User/@title
                    )" \
                    -i ".//TranscodeSession[@videoDecision='transcode' or @audioDecision='transcode']" \
                        -o " •" \
                    -b \
                    -n)
                
                # Clean up the output to ensure proper spacing between entries
                currently_playing=$(echo "$currently_playing" | sed '/^[[:space:]]*$/d' | sed 'a\\' | sed '$d')
                
                # Add extra line breaks between entries
                currently_playing=$(echo "$currently_playing" | sed 's/\([^[:space:]]\)\n\([^[:space:]]\)/\1\n\n\2/g')
            fi
            
            if [ -n "$currently_playing" ]; then
                safe_echo ""
                safe_echo "Now Playing on ${server_name} (${italic_start}${orange_color}Plex${reset}):${reset}"
                while IFS= read -r line; do
                    if [ -n "$line" ]; then
                        decoded_line=$(decode_html_entities "$line")
                        if [[ "$decoded_line" != *".................."* || "$decoded_line" =~ [^\.] ]]; then
                            case "$decoded_line" in
                                *"Transcoding:"* | \
                                *"Stream:"* | \
                                *"Media Info:"* | \
                                *"Source:"* | \
                                *"File:"* | \
                                *"Player:"*)
                                    safe_echo "${blue_color}${decoded_line}${reset}"
                                    ;;
                                *)
                                    safe_echo "${green_color}${decoded_line}${reset}"
                                    ;;
                            esac
                        fi
                    fi
                done <<< "$currently_playing"
            fi
        fi
    fi
}

check_jellyfin() {
    if [ "$JELLYFIN_ENABLED" = true ] && [ -n "$JELLYFIN_API_KEY" ]; then
        local jellyfin_json
        jellyfin_json=$(curl -s "${JELLYFIN_URL}/Sessions?api_key=${JELLYFIN_API_KEY}")
        
        if [ -n "$jellyfin_json" ]; then
            local server_name
            server_name=$(get_jellyfin_server_name)
            local currently_playing
            if [ "$VERBOSE" = true ]; then
                currently_playing=$(echo "$jellyfin_json" | \
                    jq -r '.[] | select(.NowPlayingItem != null) | 
                    (if .NowPlayingItem.Type == "Audio" then
                        if .NowPlayingItem.AlbumArtist != null and .NowPlayingItem.AlbumArtist != "" then
                            .NowPlayingItem.AlbumArtist + " - " + .NowPlayingItem.Name
                        else
                            .NowPlayingItem.Name
                        end
                    elif .NowPlayingItem.SeriesName != null and .NowPlayingItem.SeriesName != "" then
                        .NowPlayingItem.SeriesName + " - " + .NowPlayingItem.Name
                    else
                        .NowPlayingItem.Name
                    end + " ..................." + .UserName) + 
                    "\n    Media Info: " + 
                    if .NowPlayingItem.RunTimeTicks then
                        if .NowPlayingItem.RunTimeTicks > 0 then
                            ((.NowPlayingItem.RunTimeTicks/10000000/60 | floor | tostring) + " min")
                        else
                            "Live TV"
                        end
                    else
                        "Live TV"
                    end +
                    "\n    Container: " + (.NowPlayingItem.Container // "Unknown") +
                    ", Resolution: " + ((.NowPlayingItem.Width | tostring) + "x" + (.NowPlayingItem.Height | tostring) // "Unknown") +
                    if .NowPlayingItem.MediaStreams then
                        "\n    Audio Info: " + 
                        if (.NowPlayingItem.MediaStreams | map(select(.Type == "Audio")) | length) > 0 then
                            (.NowPlayingItem.MediaStreams | map(select(.Type == "Audio"))[0] | 
                            "Channels: " + (.Channels | tostring) + 
                            ", Codec: " + .Codec +
                            ", Language: " + (.Language // "Unknown"))
                        else
                            "No audio stream found"
                        end
                    else
                        "\n    Audio Info: Unknown"
                    end +
                    "\n    Player Info: " + (.Client // "Unknown") + " on " + (.DeviceName // "Unknown") +
                    "\n    Playback: " + .PlayState.PlayMethod')
            else
                currently_playing=$(echo "$jellyfin_json" | \
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
            fi
            
            if [ -n "$currently_playing" ]; then
                if [ "$VERBOSE" = false ]; then
                    # Use sed with basic regular expressions for better compatibility
                    currently_playing=$(printf '%s' "$currently_playing" | sed 's/Transcode/•/g')
                    currently_playing=$(printf '%s' "$currently_playing" | sed 's/DirectPlay//g')
                fi
                
                safe_echo ""
                safe_echo "Now Playing on ${server_name} (${italic_start}${blue_color}Jellyfin${reset}):${reset}"
                while IFS= read -r line; do
                    if [ -n "$line" ]; then
                        case "$line" in
                            *"Transcoding:"* | \
                            *"Playback:"* | \
                            *"Video Stream:"* | \
                            *"Audio Stream:"* | \
                            *"Media Info:"* | \
                            *"Source:"* | \
                            *"Container:"* | \
                            *"Direct Playing:"* | \
                            *"Player Info:"* | \
                            *"Progress:"* | \
                            *"Hardware Acceleration:"* | \
                            *"Audio Info:"* | \
                            *"Subtitles:"*)
                                safe_echo "${blue_color}${line}${reset}"
                                ;;
                            *)
                                safe_echo "${green_color}${line}${reset}"
                                ;;
                        esac
                    fi
                done <<< "$currently_playing"
            fi
        fi
    fi
}

main() {
    check_dependencies
    
    while getopts "vud" opt; do
        case ${opt} in
            v )
                show_version
                exit 0
                ;;
            u )
                update_script
                exit 0
                ;;
            d )
                VERBOSE=true
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
    
    if { [ "$JELLYFIN_ENABLED" = true ] && [ -n "$JELLYFIN_API_KEY" ]; } || \
       { [ "$PLEX_ENABLED" = true ] && [ -n "$PLEX_TOKEN" ]; }; then
        safe_echo ""
    fi
}

main "$@"
