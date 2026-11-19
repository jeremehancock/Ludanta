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

# Recommended: keep your settings in a settings file instead of typing them in below.
# That keeps your Plex token and Jellyfin API key out of this script, out of the
# backups made when updating, and out of anything you copy or share.
# Ludanta reads ~/.config/ludanta/config if it exists, or the file named in the
# LUDANTA_CONFIG environment variable. Environment variables with the same names
# as the settings below work too. See the README for examples.
LUDANTA_CONFIG="${LUDANTA_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/ludanta/config}"
[ -f "$LUDANTA_CONFIG" ] && . "$LUDANTA_CONFIG"

# To type a setting in here instead, replace the whole value, for example:
#   PLEX_TOKEN="your-plex-token"
# A value typed in here wins over the settings file and environment variables.

# Plex Configuration
PLEX_ENABLED="${PLEX_ENABLED:-true}"            # Set to false to disable Plex checking
PLEX_URL="${PLEX_URL:-http://localhost:32400}"
PLEX_TOKEN="${PLEX_TOKEN:-}"

# Jellyfin Configuration
JELLYFIN_ENABLED="${JELLYFIN_ENABLED:-true}"    # Set to false to disable Jellyfin checking
JELLYFIN_URL="${JELLYFIN_URL:-http://localhost:8096}"
JELLYFIN_API_KEY="${JELLYFIN_API_KEY:-}"

########################################################################################################
################################### DO NOT EDIT ANYTHING BELOW #########################################
########################################################################################################

VERSION="1.2.0"
VERBOSE=false
UPDATE_URL="https://raw.githubusercontent.com/jeremehancock/Ludanta/main/ludanta.sh"

# Settings that can be typed into this script. Updates carry them over.
SETTING_NAMES="PLEX_ENABLED PLEX_URL PLEX_TOKEN JELLYFIN_ENABLED JELLYFIN_URL JELLYFIN_API_KEY"
# The ones that are secret. Updates leave them out of backups.
SECRET_SETTING_NAMES="PLEX_TOKEN JELLYFIN_API_KEY"

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

# Query the Jellyfin API using the Authorization header. Newer Jellyfin
# releases reject the legacy "api_key" query parameter.
jellyfin_get() {
    curl -s -H "Authorization: MediaBrowser Token=\"${JELLYFIN_API_KEY}\"" "${JELLYFIN_URL}$1"
}

get_jellyfin_server_name() {
    if [ "$JELLYFIN_ENABLED" = true ] && [ -n "$JELLYFIN_API_KEY" ]; then
        local server_info
        server_info=$(jellyfin_get "/System/Info")
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
    remote_version=$(curl -s -H "Cache-Control: no-cache" "$UPDATE_URL" | grep -a "^VERSION=" | cut -d'"' -f2)

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
    remote_version=$(curl -s -H "Cache-Control: no-cache" "$UPDATE_URL" | grep -a "^VERSION=" | cut -d'"' -f2)

    if [ -z "$remote_version" ]; then
        echo "Error: Could not fetch remote version"
        return 1
    fi

    # Only update to a newer version, never an older one
    if [ "$remote_version" = "$VERSION" ] || \
       [ "$(printf '%s\n' "$remote_version" "$VERSION" | sort -V | tail -n1)" != "$remote_version" ]; then
        echo "No updates available. You are running the latest version (v${VERSION})."
        return 0
    fi

    printf "Update available: v%s → v%s\n" "$VERSION" "$remote_version"

    printf "Do you want to proceed with the update? [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Update cancelled."
        return 0
    fi

    local script_path="$0"
    local script_dir
    script_dir=$(cd "$(dirname "$script_path")" && pwd)
    local backup_dir="${script_dir}/backups"
    local backup_file="${backup_dir}/$(basename "$script_path").v${VERSION}.backup"
    local new_file="${script_path}.new.$$"

    # Download to a separate file first, so a failed download never touches the working script
    # and only accept something that really is a complete Ludanta script
    if ! curl -s -f -H "Cache-Control: no-cache" -o "$new_file" -L "$UPDATE_URL" || \
       [ "$(head -n 1 "$new_file")" != "#!/bin/bash" ] || \
       ! grep -aq "^VERSION=\"${remote_version}\"" "$new_file" || \
       ! grep -aq "^main \"\$@\"" "$new_file" || \
       ! bash -n "$new_file" 2>/dev/null; then
        rm -f "$new_file"
        echo "Update failed: could not download the new version. Nothing was changed."
        return 1
    fi

    # Carry over any settings typed into this script
    local name value carried_secret=false
    for name in $SETTING_NAMES; do
        value=$(typed_in_value "$script_path" "$name")
        if [ -n "$value" ]; then
            set_setting_line "$new_file" "$name" "${name}=\"${value}\""
            case " $SECRET_SETTING_NAMES " in *" $name "*) carried_secret=true ;; esac
        fi
    done

    # Back up the current version, with any token or API key removed
    mkdir -p "$backup_dir"
    cp "$script_path" "$backup_file"
    for name in $SECRET_SETTING_NAMES; do
        if [ -n "$(typed_in_value "$backup_file" "$name")" ]; then
            set_setting_line "$backup_file" "$name" "${name}=\"\"  # removed from this backup"
        fi
    done

    chmod +x "$new_file"
    mv "$new_file" "$script_path"
    echo "Successfully updated to v${remote_version}"
    echo "Previous version backed up to $backup_file (without your token or API key)"
    if $carried_secret; then
        echo ""
        echo "Tip: your Plex token or Jellyfin API key is typed into this script."
        echo "Moving it to a settings file keeps it out of the script and anything you share:"
        echo "https://github.com/jeremehancock/Ludanta#configuration"
    fi

    exit 0
}

# Prints the value typed into a script file for one setting ($1 = file, $2 = name).
# Prints nothing if the line still reads from the settings file or environment
# (its value contains a $), or if the value is empty.
typed_in_value() {
    local line value
    line=$(grep -a "^$2=" "$1" | head -n 1)
    [ -z "$line" ] && return 0
    value=${line#*=}
    case "$value" in
        \"*) value=${value#\"}; value=${value%%\"*} ;;
        *)   value=${value%%[[:space:]#]*} ;;
    esac
    case "$value" in
        *'$'*) return 0 ;;
    esac
    printf '%s' "$value"
}

# Replaces the line that sets one setting in a file ($1 = file, $2 = name, $3 = new line).
# Plain bash, so it works the same on Linux and macOS.
set_setting_line() {
    local tmp="$1.tmp.$$" line
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            "$2="*) printf '%s\n' "$3" ;;
            *)      printf '%s\n' "$line" ;;
        esac
    done < "$1" > "$tmp" && mv "$tmp" "$1"
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

check_plex() {
    if [ "$PLEX_ENABLED" = true ] && [ -n "$PLEX_TOKEN" ]; then
        local plex_xml
        plex_xml=$(curl -s "${PLEX_URL}/status/sessions?X-Plex-Token=${PLEX_TOKEN}")
        
        if [ -n "$plex_xml" ]; then
            local server_name
            server_name=$(get_plex_server_name)
            local currently_playing
            if [ "$VERBOSE" = true ]; then
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
                
                currently_playing=$(echo "$currently_playing" | sed '/^[[:space:]]*$/d' | sed 'a\\' | sed '$d')
                currently_playing=$(echo "$currently_playing" | sed 's/\([^[:space:]]\)\n\([^[:space:]]\)/\1\n\n\2/g')
            fi
            
            # Display server header regardless of playback status
            safe_echo ""
            safe_echo "Now Playing on ${server_name} (${italic_start}${orange_color}Plex${reset}):${reset}"
            
            if [ -n "$currently_playing" ] && [ "$(echo "$currently_playing" | tr -d '[:space:]')" != "" ]; then
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
            else
                safe_echo "${green_color}${italic_start}Nothing playing${reset}"
            fi
        fi
    fi
}

check_jellyfin() {
    if [ "$JELLYFIN_ENABLED" = true ] && [ -n "$JELLYFIN_API_KEY" ]; then
        local jellyfin_json
        jellyfin_json=$(jellyfin_get "/Sessions")
        
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
            
            # Display server header regardless of playback status
            safe_echo ""
            safe_echo "Now Playing on ${server_name} (${italic_start}${blue_color}Jellyfin${reset}):${reset}"
            
            if [ -n "$currently_playing" ] && [ "$(echo "$currently_playing" | tr -d '[:space:]')" != "" ]; then
                if [ "$VERBOSE" = false ]; then
                    currently_playing=$(printf '%s' "$currently_playing" | sed 's/Transcode/•/g')
                    currently_playing=$(printf '%s' "$currently_playing" | sed 's/DirectPlay//g')
                fi
                
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
            else
                safe_echo "${green_color}${italic_start}Nothing playing${reset}"
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
                echo "Usage: $0 [-v] [-u] [-d]"
                echo "Options:"
                echo "  -v    Show version"
                echo "  -u    Update script"
                echo "  -d    Show detailed information"
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
