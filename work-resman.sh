#!/bin/bash

# Global variables for timer management
end_time=0
timer_pid=""
TERMINAL_WINDOW_IDS=()

# Function to clear previous lines
clear_lines() {
    local lines=$1
    for ((i=0; i<lines; i++)); do
        echo -en "\033[1A\033[2K"
    done
}

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

# Function to validate duration and convert to seconds
validate_duration() {
    local input=$1
    # Check if input is a valid number (integer or float)
    if ! [[ "$input" =~ ^[0-9]*\.?[0-9]+$ ]] || [ "$(echo "$input <= 0" | bc)" -eq 1 ]; then
        echo 1800  # 30 minutes in seconds
    else
        # Convert to seconds (multiply by 60 to convert minutes to seconds)
        echo "scale=0; $input * 60" | bc
    fi
}

# Function to focus terminal window
focus_terminal() {
    osascript -e 'tell application "Terminal" to activate'
}

# Function to close specific terminal windows
close_dev_terminals() {
    # First kill any running dev processes
    pkill -f "npm run dev"
    pkill -f "meteor run"
    
    # Small delay to ensure processes are terminated
    sleep 1
    
    # Load any stored terminal IDs
    load_terminal_ids

    for window_id in "${TERMINAL_WINDOW_IDS[@]}"; do
        if [ ! -z "$window_id" ]; then
            osascript <<EOF
                tell application "Terminal"
                    try
                        repeat with w in windows
                            try
                                if id of w is $window_id then
                                    close w saving no
                                end if
                            end try
                        end repeat
                    end try
                end tell
EOF
        fi
    done
    
    # Clear the window IDs array and temp file
    TERMINAL_WINDOW_IDS=()
    rm -f /tmp/dev_terminal_ids
}

# Function to close applications
close_apps() {
    # Close the terminal windows first
    # close_dev_terminals

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

# Function to load environment variables
load_env_vars() {
    # Check for Zeki environment file
    if [ -f "/Users/resman/Projects/resman-projects/envs/.env.zeki" ]; then
        export $(cat /Users/resman/Projects/resman-projects/envs/.env.zeki | xargs)
    else
        echo "Error: .env.zeki file not found in envs directory"
        exit 1
    fi

    # Check for Zeki V2 environment file
    if [ -f "/Users/resman/Projects/resman-projects/envs/.env.zeki-v2" ]; then
        export $(cat /Users/resman/Projects/resman-projects/envs/.env.zeki-v2 | xargs)
    else
        echo "Error: .env.zeki-v2 file not found in envs directory"
        exit 1
    fi

    # Check for MyRazz SSR environment file 
    if [ -f "/Users/resman/Projects/resman-projects/envs/.env.myrazz-ssr" ]; then
        export $(cat /Users/resman/Projects/resman-projects/envs/.env.myrazz-ssr | xargs)
    else
        echo "Error: .env.myrazz-ssr file not found in envs directory"
        exit 1
    fi
}

# Function to start dev servers with improved error handling
start_dev_servers() {
    echo "Starting dev servers..."

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
            do script "cd /Users/resman/Projects/resman-projects/zeki/packages/dashboard && pkill -f 'meteor run' || true && sleep 2 && source /Users/resman/Projects/resman-projects/envs/.env.zeki && meteor run --settings settings-local.json --port 4000" in win
            
            # Create and setup second tab
            tell application "System Events" to keystroke "t" using command down
            delay 5
            do script "cd /Users/resman/Projects/resman-projects/zeki/packages/frontend && source /Users/resman/Projects/resman-projects/envs/.env.zeki && meteor run --settings settings-local.json" in window 1
            delay 5
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
            do script "cd /Users/resman/Projects/resman-projects/myrazz-ssr && source /Users/resman/Projects/resman-projects/envs/.env.myrazz-ssr && export \$(cat /Users/resman/Projects/resman-projects/envs/.env.myrazz-ssr | xargs) && NODE_OPTIONS='--loader ts-node/esm' /Users/resman/.nvm/versions/node/v20.13.1/bin/npm run dev --workspace=viewer" in window 1
            
            # Create and setup third tab - Server Dev
            tell application "System Events" to keystroke "t" using command down
            delay 5
            do script "cd /Users/resman/Projects/resman-projects/myrazz-ssr && source /Users/resman/Projects/resman-projects/envs/.env.myrazz-ssr && export \$(cat /Users/resman/Projects/resman-projects/envs/.env.myrazz-ssr | xargs) && NODE_OPTIONS='--loader ts-node/esm' /Users/resman/.nvm/versions/node/v20.13.1/bin/npm run dev --workspace=server" in window 1
            
            return win_id
        end tell
EOF
    )
    store_terminal_id "$WINDOW2_ID"

    # Open third Terminal window for serverless
    WINDOW3_ID=$(osascript <<EOF
        tell application "Terminal"
            # Create new window and get its ID
            set win to do script ""
            set win_id to id of window 1
            
            do script "cd /Users/resman/Projects/resman-projects/zeki-v2/serverless && ln -sf /Users/resman/Projects/resman-projects/envs/.env.zeki-v2 .env && set -a && . /Users/resman/Projects/resman-projects/envs/.env.zeki-v2 && set +a && TH=1 npm run dev" in win

            return win_id
        end tell
EOF
    )
    store_terminal_id "$WINDOW3_ID"
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
    local warning_shown=false
    local display_lines=4
    
    # Initial display of menu options
    echo -e "\nTimer Control Menu:"
    echo "1) Set new duration"
    echo "2) Close now"
    echo -e "\nTime remaining: calculating..."
    
    while true; do
        current_time=$(date +%s)
        # Use bc for arithmetic and round to nearest integer
        remaining_seconds=$(echo "scale=0; ($end_time - $current_time)/1" | bc)
        
        if [ "$remaining_seconds" -le 0 ]; then
            echo -e "\nTime's up! Closing applications..."
            close_apps "$profile_path" "${apps[@]}"
            return
        fi
        
        # Use bc for division and modulo, round to nearest integer
        minutes=$(echo "scale=0; $remaining_seconds / 60" | bc)
        seconds=$(echo "scale=0; $remaining_seconds % 60" | bc)
        
        # Show warning at 1 minute remaining
        if [ "$minutes" -eq 0 ] && [ "$seconds" -le 60 ] && [ $warning_shown = false ]; then
            warning_shown=true
            focus_terminal
            clear_lines 1  # Clear only the time remaining line
            echo -e "\n⚠️  1 MINUTE REMAINING!"
            echo "Press 1 to extend time or 2 to close now"
            echo -e "Time remaining: ${minutes}m ${seconds}s"
            continue
        fi
        
        if [ $warning_shown = false ]; then
            # Just update the time line
            echo -en "\033[1A\033[2K"  # Clear only the last line
            echo -e "Time remaining: ${minutes}m ${seconds}s"
        else
            # When warning is shown, just update the last line
            echo -en "\033[1A\033[2K"
            echo -e "Time remaining: ${minutes}m ${seconds}s"
        fi
        
        # Check for input with a timeout
        read -t 1 -n 1 action
        
        if [[ $? -eq 0 ]]; then
            case $action in
                1)
                    echo
                    read -p "Enter new duration in minutes: " new_duration
                    duration_seconds=$(validate_duration "$new_duration")
                    # Use bc for end time calculation
                    end_time=$(echo "$(date +%s) + $duration_seconds" | bc)
                    warning_shown=false  # Reset warning flag
                    clear_lines 6  # Clear the warning messages
                    echo -e "\nTimer Control Menu:"
                    echo "1) Set new duration"
                    echo "2) Close now"
                    echo -e "\nTime remaining: calculating..."
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
duration_seconds=$(validate_duration "$duration")

# Start the dev servers
# start_dev_servers

# Wait for servers to start
sleep 10

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
apps=("Cursor" "Sublime Text" "Studio 3T" "Github Desktop" "Slack" "Microsoft Teams" "PhpStorm")
open_apps "${apps[@]}"

# Set initial end time using bc for calculation
end_time=$(echo "$(date +%s) + $duration_seconds" | bc)

# Start countdown and menu display with profile path and apps
display_countdown_and_menu "$profile_path" "${apps[@]}"