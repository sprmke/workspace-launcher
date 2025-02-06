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

# Function to focus terminal window
focus_terminal() {
    osascript -e 'tell application "Terminal" to activate'
}

# Function to display countdown and menu
display_countdown_and_menu() {
    local profile_path=$1
    shift
    local apps=("$@")
    local warning_shown=false
    local display_lines=4
    
    # Initial display of menu options (only once)
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

# Main script
# Get duration with default value of 30 minutes
clear
echo -e "\nLaunch mode:"
echo "1) Essential apps only"
echo "2) All apps"
read -p "Enter choice (1-2): " launch_mode

read -p "Enter duration in minutes before auto-close [30]: " duration
duration=${duration:-30}  # Set default to 30 if empty
duration_seconds=$(validate_duration "$duration")

# Store profile path and apps
profile_path="Default"

# Define essential and all apps/URLs
essential_urls=(
    "http://localhost:5173/"
    "https://trello.com/b/iWR71DXf/web-app"
    "https://bitbucket.org/auristech/fonetti-web/commits/branch/main"
)
all_urls=(
    "https://miro.com/app/board/uXjVPvGoz9U=/"
    "https://app.bugsnag.com/auris-tech-ltd/fonetti-web-app/errors"
)
# Essential apps
essential_apps=("Windsurf" "Github Desktop" "Slack")
# Additional apps
all_apps=("Postman 2" "Obsedian" "Teams")

# Start the dev server
echo "Starting dev server..."
start_dev_server

# Wait a bit for the dev server to start
sleep 3

# Open Chrome with specified profile and URLs based on launch mode
echo "Starting Chrome with specified URLs..."
if [ "$launch_mode" = "1" ]; then
    open_chrome "$profile_path" "${essential_urls[@]}"
    apps=("${essential_apps[@]}")
else
    open_chrome "$profile_path" "${essential_urls[@]}" "${all_urls[@]}"
    apps=("${essential_apps[@]}" "${all_apps[@]}")
fi

# Open applications
echo "Starting applications..."
open_apps "${apps[@]}"

# Set initial end time using bc for calculation
end_time=$(echo "$(date +%s) + $duration_seconds" | bc)

# Start countdown and menu display with profile path and apps
display_countdown_and_menu "$profile_path" "${apps[@]}"