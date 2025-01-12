#!/bin/bash

# Global variables for timer management
end_time=0
timer_pid=""

# Function to clear previous lines
clear_lines() {
    local lines=$1
    for ((i=0; i<lines; i++)); do
        echo -en "\033[1A\033[2K"
    done
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

# Function to close applications
close_apps() {
    # Close the specific terminal window first
    close_dev_terminal

    local profile_path=$1
    
    # Close Chrome windows // TODO: Close specific profile only
    osascript -e "tell application \"Google Chrome\" to quit"
    
    # Close other applications if provided
    shift
    for app in "$@"; do
        osascript -e "tell application \"$app\" to quit"
    done

    # Kill the dev server process
    pkill -f "pnpm dev"
}

# Function to open Chrome with specific profile and URLs in a single window
open_chrome() {
    profile_path=$1
    shift
    first_url=$1
    shift
    
    # Open first URL in a new window and redirect output to /dev/null
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

# Add global variable to store terminal window ID
TERMINAL_WINDOW_ID=""

# Function to start dev server
start_dev_server() {
    # Check if port 5173 is in use and kill the process if it exists
    if lsof -i :5173 > /dev/null; then
        echo "Port 5173 is in use. Killing existing process..."
        kill $(lsof -ti :5173)
        sleep 1
    fi

    # Open Terminal and run dev server, storing the window ID
    TERMINAL_WINDOW_ID=$(osascript <<EOF
        tell application "Terminal"
            activate
            set newWindow to do script "cd /Users/auris/Projects/auris-projects/fonetti-web && pnpm dev"
            return id of window 1
        end tell
EOF
    )
}

# Function to close specific terminal window
close_dev_terminal() {
    if [ ! -z "$TERMINAL_WINDOW_ID" ]; then
        osascript <<EOF
            tell application "Terminal"
                repeat with w in windows
                    if id of w is $TERMINAL_WINDOW_ID then
                        close w
                        exit repeat
                    end if
                end repeat
            end tell
EOF
    fi
}

# Function to display countdown and menu
display_countdown_and_menu() {
    local profile_path=$1
    shift
    local apps=("$@")
    
    # Initial display of menu options (only once)
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

# Get duration with default value of 30 minutes
read -p "Enter duration in minutes before auto-close [30]: " duration
duration=${duration:-30}  # Set default to 30 if empty
duration=$(validate_duration "$duration")

# Store profile path and apps
profile_path="Default"
apps=("Windsurf" "Github Desktop" "Sublime Text" "Slack" "Teams")

# Start the dev server
start_dev_server

# Wait a bit for the dev server to start
sleep 3

# Open Chrome with specified profile and URLs
open_chrome "$profile_path" \
    "http://localhost:5173/" \
    "https://trello.com/b/iWR71DXf/web-app" \
    "https://miro.com/app/board/uXjVPvGoz9U=/" \
    "https://bitbucket.org/auristech/fonetti-web/commits/branch/main" \
    "https://app.bugsnag.com/auris-tech-ltd/fonetti-web-app/errors" \
    "https://docs.google.com/document/d/13vxiPW3W9snzwULGKxC34rY-Y9RpEEFuGpxWu5z6xG8/edit?tab=t.pd1f1vugt095#heading=h.mbkujqfm82" \
    "https://docs.google.com/document/d/1x5yYzUH71q0u-DhZt-8Oeh7SukuMSOoLr2f2jQvpxj4/edit?tab=t.0#heading=h.y7bxmbmchq97"

# Open applications
open_apps "${apps[@]}"

# Set initial end time
end_time=$(($(date +%s) + duration * 60))

# Start countdown and menu display with profile path and apps
display_countdown_and_menu "$profile_path" "${apps[@]}"