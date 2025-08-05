#!/bin/bash

# ENVIRONMENT VARIABLES REQUIRED:
# Before running this script, set these environment variables:
# export API_KEY="your_api_key"
# export AWS_ACCESS_KEY_ID="your_aws_access_key_id"  
# export AWS_REGION="us-east-1"
# export AWS_SECRET_ACCESS_KEY="your_aws_secret_access_key"
# export RESMAN_INTEGRATION_PARTNER_ID="your_partner_id"
# export SENDGRID_API_KEY="your_sendgrid_api_key"
# export UPLOADCARE_PRIVATE="your_uploadcare_private_key"
# export UPLOADCARE_PUBLIC="your_uploadcare_public_key"
# export YELP_AUTH="your_yelp_auth_token"

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
    pkill -f "meteor run"
}



# Function to check and kill processes on specific ports
check_and_kill_ports() {
    echo "Checking and cleaning up ports..."
    
    # Kill any existing meteor and npm processes first
    if pgrep -f "meteor run" > /dev/null; then
        echo "Killing existing Meteor processes..."
        pkill -f "meteor run"
        sleep 2
    fi
    
    if pgrep -f "npm run dev" > /dev/null; then
        echo "Killing existing npm run dev processes..."
        pkill -f "npm run dev"
        sleep 2
    fi

    # Check and kill processes on specific ports (including common dev server ports)
    for port in 4000 3000 3001 3005 3006 3007 5173 8080; do
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

# Function to start dev servers
start_dev_servers() {
    local selected_projects=("$@")
    
    echo "Starting dev servers for selected projects..."
    
    # Start selected projects
    for project in "${selected_projects[@]}"; do
        case $project in
            "zeki")
                echo "Starting zeki (dashboard)..."
                window_id=$(osascript <<EOF
                    tell application "Terminal"
                        activate
                        set newWindow to do script "cd /Users/resman/Projects/zeki/packages/dashboard && MONGODB_FRONTEND_URI=mongodb://localhost:3001/meteor MONGODB_FRONTEND_V2_URI=mongodb://localhost:27018/sites SERVICES=cron,lead,conversation,email,importer,app,share,siteImporter,taskScheduler,taskRunner,appList,library,imageUploadQueue,migration,layer,integrationScheduler,jobScheduler,rentCafeScheduler,rolesSync,apiLogsReportScheduler,platformAnalyticsRunner,platformAnalyticsReportRunner,screensSSRSync PATH=\$PATH:/Users/resman/.meteor /Users/resman/.nvm/versions/node/v14.21.3/bin/npm run dev"
                        return id of window 1
                    end tell
EOF
                )
                store_terminal_id "$window_id"
                ;;
            "myrazz-ssr")
                echo "Starting myrazz-ssr..."
                window_id=$(osascript <<EOF
                    tell application "Terminal"
                        activate
                        set newWindow to do script "cd /Users/resman/Projects/resman-projects/myrazz-ssr && MONGODB_URI=mongodb://localhost:27018/sites npm run dev --workspace=editor"
                        return id of window 1
                    end tell
EOF
                )
                store_terminal_id "$window_id"
                ;;
            "zeki-v2")
                echo "Starting zeki-v2 (serverless)..."
                window_id=$(osascript <<EOF
                    tell application "Terminal"
                        activate
                        set newWindow to do script "cd /Users/resman/Projects/resman-projects/zeki-v2/serverless && API_KEY=$API_KEY AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_REGION=$AWS_REGION AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY RESMAN_INTEGRATION_PARTNER_ID=$RESMAN_INTEGRATION_PARTNER_ID SENDGRID_API_KEY=$SENDGRID_API_KEY UPLOADCARE_PRIVATE=$UPLOADCARE_PRIVATE UPLOADCARE_PUBLIC=$UPLOADCARE_PUBLIC YELP_AUTH=$YELP_AUTH npm run dev"
                        return id of window 1
                    end tell
EOF
                )
                store_terminal_id "$window_id"
                ;;
        esac
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

# Clear screen and show project selection menu
clear
echo -e "\nResman Development Environment Setup"
echo -e "===================================="

# Project selection menu
echo -e "\nSelect projects to start:"
echo "1) zeki"
echo "2) myrazz-ssr"
echo "3) zeki-v2 (serverless) - Serverless functions"
echo "4) All projects"
echo "5) No dev servers (apps only)"
read -p "Enter project choice(s) separated by spaces (e.g., 1 3): " project_choices

# Parse project selections
selected_projects=()
if [[ " $project_choices " =~ " 4 " ]]; then
    selected_projects=("zeki" "myrazz-ssr" "zeki-v2")
else
    for choice in $project_choices; do
        case $choice in
            1) selected_projects+=("zeki") ;;
            2) selected_projects+=("myrazz-ssr") ;;
            3) selected_projects+=("zeki-v2") ;;
        esac
    done
fi

# Get duration with default value of 30 minutes
read -p "Enter duration in minutes before auto-close [Press Enter for no auto-close]: " duration

# Only proceed with timer if duration was provided
if [ -n "$duration" ]; then
    duration_seconds=$(validate_duration "$duration")
    # Set initial end time using bc for calculation
    end_time=$(echo "$(date +%s) + $duration_seconds" | bc)
fi

# Clean up ports before starting
if [ ${#selected_projects[@]} -gt 0 ]; then
    echo "Cleaning up ports and existing processes..."
    check_and_kill_ports
fi

# Start the dev servers for selected projects
if [ ${#selected_projects[@]} -gt 0 ]; then
    echo "Starting dev servers..."
    start_dev_servers "${selected_projects[@]}"
    
    # Wait a bit for the dev servers to start
    echo "Waiting for dev servers to initialize..."
    sleep 5
fi

# Determine Chrome URLs based on selected projects
chrome_urls=()
chrome_urls+=("https://github.com/razzinteractive/zeki/pulls")
chrome_urls+=("https://myresman.atlassian.net/jira/software/c/projects/RAZZ/boards/49")

# Add localhost URLs based on selected projects
for project in "${selected_projects[@]}"; do
    case $project in
        "zeki")
            chrome_urls+=("http://localhost:4000/")  # Dashboard runs on port 4000
            chrome_urls+=("http://localhost:3000/")  # Frontend runs on port 3000
            ;;
        "myrazz-ssr")
            chrome_urls+=("http://localhost:3000/")  # Editor workspace
            ;;
        "zeki-v2")
            chrome_urls+=("http://localhost:3005/")  # Serverless functions
            ;;
    esac
done

# Open Chrome profile with specified URLs
echo "Starting Chrome with specified URLs..."
profile_path="Default"
if [ ${#chrome_urls[@]} -gt 0 ]; then
    open_chrome "$profile_path" "${chrome_urls[@]}"
fi

# Open specified applications
echo "Starting applications..."
apps=("Github Desktop" "Slack" "Microsoft Teams" "Obsidian" "Cursor")
open_apps "${apps[@]}"

# Only start countdown and menu display if duration was provided
if [ -n "$duration" ]; then
    display_countdown_and_menu "$profile_path" "${apps[@]}"
else
    echo -e "\nNo auto-close timer set. Applications will remain open."
    echo "1) Keep apps open and return to main menu"
    echo "2) Close all apps and return to main menu"
    read -p "Enter choice (1-2): " choice
    
    if [ "$choice" = "2" ]; then
        echo -e "\nClosing applications..."
        close_apps "$profile_path" "${apps[@]}"
    fi
    clear
fi
