# Ludanta

## Now Playing on Plex/Jellyfin

Ludanta is a lightweight command-line tool that displays what's currently playing on your Plex and/or Jellyfin media servers. Get real-time updates about media playback across your servers directly in your terminal.

## Features
- Real-time playback monitoring for both Plex and Jellyfin servers
- Support for multiple media types (movies, TV shows, music, and live TV)
- Clean, color-coded output for easy reading
- Transcoding status indicators
- Built-in version checking and update mechanism
- Automatic configuration backup during updates

## Screenshots

![Ludanta](https://raw.githubusercontent.com/jeremehancock/Ludanta/main/screenshots/ludanta.png "Ludanta")

![Ludanta Detailed](https://raw.githubusercontent.com/jeremehancock/Ludanta/main/screenshots/ludanta-detailed.png "Ludanta Detailed")

## Requirements
- curl
- xmlstarlet
- jq
- tput
- Plex and/or Jellyfin server
- Plex token (for Plex monitoring)
- Jellyfin API key (for Jellyfin monitoring)

## Installation

### Quick Start
```bash
mkdir Ludanta && cd Ludanta && curl -o ludanta.sh https://raw.githubusercontent.com/jeremehancock/Ludanta/main/ludanta.sh && chmod +x ludanta.sh
```

### Manual Installation
1. Clone the repository:
```bash
git clone https://github.com/jeremehancock/Ludanta.git
```

2. Change directory:
```bash
cd Ludanta
```

3. Make the script executable:
```bash
chmod +x ludanta.sh
```

## Configuration
Edit the script and configure your server settings:

```bash
# Plex Configuration
PLEX_ENABLED=true                              # Set to false to disable Plex checking
PLEX_URL="http://localhost:32400"              # Your Plex server URL
PLEX_TOKEN=""                                  # Your Plex token (X-Plex-Token)

# Jellyfin Configuration
JELLYFIN_ENABLED=true                          # Set to false to disable Jellyfin checking
JELLYFIN_URL="http://localhost:8096"           # Your Jellyfin server URL
JELLYFIN_API_KEY=""                            # Your Jellyfin API key
```

### Finding Your Credentials
- **Plex Token**: Follow the instructions [here](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/)
- **Jellyfin API Key**: In Jellyfin, go to Dashboard → API Keys to generate a new key

## Usage
### Basic Usage
```bash
./ludanta.sh
```

### Command Line Options
```
-v    Show version information
-u    Update to latest version
-d    Show extra details for streams
```

## Output Format
Ludanta displays currently playing media in the following format:
```
Now Playing on SERVER (Plex):
Show Name - Episode Title ................... Username •

Now Playing on SERVER (Jellyfin):
Movie Title ................... Username •
```
The bullet point (•) indicates that transcoding is active for that stream.

You can also use the `-d` flag to give more details for each stream.

## Updates
Ludanta includes an automatic update system that:
- Creates backups of your current version
- Preserves your configuration settings
- Downloads the latest version from the repository
- Verifies successful updates

To update:
```bash
./ludanta.sh -u
```

## License
[MIT License](LICENSE)

## AI Assistance Disclosure
This tool was developed with assistance from AI language models.
