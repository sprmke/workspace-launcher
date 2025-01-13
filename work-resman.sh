#!/bin/bash

# Global variables for timer management
end_time=0
timer_pid=""
TERMINAL_WINDOW_IDS=()

# Cleanup function to be called on script exit
cleanup() {
    rm -f /tmp/dev_terminal_ids
}

# Set up trap for cleanup
trap cleanup EXIT

# Function to store terminal window IDs
store_terminal_id() {
    local window_id=$1
    if [ ! -z "$window_id" ]; then
        TERMINAL_WINDOW_IDS+=("$window_id")
        echo "$window_id" >> /tmp/dev_terminal_ids
    fi
}

# Function to load stored terminal IDs
load_terminal_ids() {
    if [ -f "/tmp/dev_terminal_ids" ]; then
        while IFS= read -r id; do
            TERMINAL_WINDOW_IDS+=("$id")
        done < "/tmp/dev_terminal_ids"
    fi
}

# Function to validate duration
validate_duration() {
    local input=$1
    if ! [[ "$input" =~ ^[0-9]+$ ]] || [ "$input" -le 0 ]; then
        echo 30
    else
        echo "$input"
    fi
}

# Function to close specific terminal windows
close_dev_terminals() {
    # Load any stored terminal IDs
    load_terminal_ids

    for window_id in "${TERMINAL_WINDOW_IDS[@]}"; do
        if [ ! -z "$window_id" ]; then
            osascript <<EOF
                tell application "Terminal"
                    repeat with w in windows
                        if id of w is $window_id then
                            close w saving no
                            exit repeat
                        end if
                    end repeat
                end tell
EOF
        fi
    done
    
    # Clear the window IDs array and temp file
    TERMINAL_WINDOW_IDS=()
    rm -f /tmp/dev_terminal_ids
    
    # Kill any remaining dev processes
    pkill -f "npm run dev"
}

# Function to close applications
close_apps() {
    # Close the terminal windows first
    close_dev_terminals

    local profile_path=$1
    
    # Close Chrome windows
    osascript -e "tell application \"Google Chrome\" to quit"
    
    # Close other applications if provided
    shift
    for app in "$@"; do
        osascript -e "tell application \"$app\" to quit"
    done

    # Kill all dev server processes
    pkill -f "npm run dev"
}



# Function to check and kill processes on specific ports
check_and_kill_ports() {
    echo "Checking and cleaning up ports..."
    
    # Kill any existing meteor processes first
    if pgrep -f "meteor run" > /dev/null; then
        echo "Killing existing Meteor processes..."
        pkill -f "meteor run"
        sleep 2
    fi

    # Check and kill processes on specific ports
    for port in 4000 3000 3001 3005 3006 3007; do
        if lsof -i :$port > /dev/null; then
            echo "Port $port is in use. Killing existing process..."
            kill $(lsof -ti :$port)
            sleep 1
        fi
    done

    # Double check port 4000 specifically for Meteor
    if lsof -i :4000 > /dev/null; then
        echo "Port 4000 still in use. Force killing..."
        kill -9 $(lsof -ti :4000)
        sleep 2
    fi
}

# Function to start dev servers with improved error handling
start_dev_servers() {
    # Check and kill processes on specific ports
    check_and_kill_ports

    # Clear any existing terminal IDs
    rm -f /tmp/dev_terminal_ids

    # Open first Terminal window for Zeki
    WINDOW1_ID=$(osascript <<EOF
        tell application "Terminal"
            # Create new window and get its ID
            set win to do script ""
            set win_id to id of window 1
            
            # First tab - Zeki Dashboard
            do script "cd /Users/resman/Projects/resman-projects/zeki/packages/dashboard && pkill -f 'meteor run' || true && sleep 2 && DEBUG= DEBUG_COLORS=1 MONGODB_FRONTEND_URI=mongodb://localhost:3001/meteor MONGODB_FRONTEND_V2_URI=mongodb://localhost:27018/sites SERVICES=cron,lead,conversation,email,importer,app,share,siteImporter,taskScheduler,taskRunner,appList,library,imageUploadQueue,migration,layer,integrationScheduler meteor run --settings settings-local.json --port 4000" in win
            
            # Create and setup second tab
            tell application "System Events" to keystroke "t" using command down
            delay 5
            do script "cd /Users/resman/Projects/resman-projects/zeki/packages/frontend && meteor run --settings settings-local.json" in window 1
            
            return win_id
        end tell
EOF
    )
    store_terminal_id "$WINDOW1_ID"

    # Open second Terminal window for SSR components
    WINDOW2_ID=$(osascript <<EOF
        tell application "Terminal"
            # Create new window and get its ID
            set win to do script ""
            set win_id to id of window 1
            
            # First tab - Editor Dev (no MongoDB dependency)
            do script "cd /Users/resman/Projects/resman-projects/myrazz-ssr && /Users/resman/.nvm/versions/node/v20.13.1/bin/npm run dev --workspace=editor" in win
            
            # Create and setup second tab - Viewer Dev
            tell application "System Events" to keystroke "t" using command down
            delay 5
            do script "cd /Users/resman/Projects/resman-projects/myrazz-ssr && NODE_OPTIONS='--import=./initialize.js' DEBUG=vike:error MONGODB_URI=mongodb://localhost:27018/sites /Users/resman/.nvm/versions/node/v20.13.1/bin/npm run dev --workspace=viewer" in window 1
            
            # Create and setup third tab - Server Dev
            tell application "System Events" to keystroke "t" using command down
            delay 5
            do script "cd /Users/resman/Projects/resman-projects/myrazz-ssr && NODE_OPTIONS='--import=./initialize.js' MONGODB_URI=mongodb://localhost:27018/sites NODE_ENV=development HOSTNAME=local /Users/resman/.nvm/versions/node/v20.13.1/bin/npm run dev --workspace=server" in window 1
            
            return win_id
        end tell
EOF
    )
    store_terminal_id "$WINDOW2_ID"
}

# Function to open Chrome with specific profile and URLs in a single window
open_chrome() {
    profile_path=$1
    shift
    first_url=$1
    shift
    
    # Open first URL in a new window
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        --profile-directory="$profile_path" \
        --new-window \
        "$first_url" > /dev/null 2>&1 &
    
    # Wait a bit for the window to open
    sleep 2
    
    # Open remaining URLs in new tabs in the same window
    for url in "$@"; do
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
            --profile-directory="$profile_path" \
            --new-tab \
            "$url" > /dev/null 2>&1
    done
}

# Function to open applications
open_apps() {
    for app in "$@"; do
        osascript -e "tell application \"$app\" to activate"
    done
}

# Function to display countdown and menu
display_countdown_and_menu() {
    local profile_path=$1
    shift
    local apps=("$@")
    
    # Initial display of menu options
    echo -e "\nTimer Control Menu:"
    echo "1) Set new duration"
    echo "2) Close now"
    echo -e "\nTime remaining: calculating..."
    
    while true; do
        current_time=$(date +%s)
        remaining_seconds=$((end_time - current_time))
        
        if [ $remaining_seconds -le 0 ]; then
            echo -e "\nTime's up! Closing applications..."
            close_apps "$profile_path" "${apps[@]}"
            return
        fi
        
        minutes=$((remaining_seconds / 60))
        seconds=$((remaining_seconds % 60))
        
        # Move cursor up 1 line and clear the time remaining line
        echo -en "\033[1A\033[2K"
        # Display the new time
        echo -e "Time remaining: ${minutes}m ${seconds}s"
        
        # Check for input with a timeout
        read -t 1 -n 1 action
        
        if [[ $? -eq 0 ]]; then
            case $action in
                1)
                    echo
                    read -p "Enter new duration in minutes: " new_duration
                    new_duration=$(validate_duration "$new_duration")
                    end_time=$(($(date +%s) + new_duration * 60))
                    ;;
                2)
                    echo -e "\nClosing applications..."
                    close_apps "$profile_path" "${apps[@]}"
                    return
                    ;;
            esac
        fi
    done
}

# Main script execution

# Get duration with default value of 30 minutes
read -p "Enter duration in minutes before auto-close [30]: " duration
duration=${duration:-30}  # Set default to 30 if empty
duration=$(validate_duration "$duration")

# Start the dev servers
echo "Starting dev servers..."
start_dev_servers

# Open Chrome profile with specified URLs
echo "Starting Chrome with specified URLs..."
profile_path="Profile 12"
open_chrome "$profile_path" \
    "http://localhost:4000/" \
    "https://github.com/razzinteractive/zeki/pulls" \
    "https://myresman.atlassian.net/jira/software/c/projects/RAZZ/boards/49" \
    "https://chatgpt.com/"

# Open specified applications
echo "Starting applications..."
apps=("PhpStorm" "Cursor" "Sublime Text" "Studio 3T" "Github Desktop" "Slack" "Microsoft Teams")
open_apps "${apps[@]}"

# Set initial end time
end_time=$(($(date +%s) + duration * 60))

# Start countdown and menu display with profile path and apps
display_countdown_and_menu "$profile_path" "${apps[@]}"