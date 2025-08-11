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

# Store terminal window IDs
store_terminal_id() {
    local window_id=$1
    if [ ! -z "$window_id" ]; then
        TERMINAL_WINDOW_IDS+=("$window_id")
        echo "$window_id" >> /tmp/dev_terminal_ids
    fi
}

# Load stored terminal IDs
load_terminal_ids() {
    if [ -f "/tmp/dev_terminal_ids" ]; then
        while IFS= read -r id; do
            TERMINAL_WINDOW_IDS+=("$id")
        done < "/tmp/dev_terminal_ids"
    fi
}

# Validate duration and convert to seconds
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

# Check and kill processes on specific ports
check_and_kill_ports() {
    echo "Checking and cleaning up ports..."
    
    # Kill any existing bun and npm processes first
    if pgrep -f "bun dev" > /dev/null; then
        echo "Killing existing bun dev processes..."
        pkill -f "bun dev"
        sleep 2
    fi
    
    if pgrep -f "npm run dev" > /dev/null; then
        echo "Killing existing npm run dev processes..."
        pkill -f "npm run dev"
        sleep 2
    fi

    if pgrep -f "sst dev" > /dev/null; then
        echo "Killing existing sst dev processes..."
        pkill -f "sst dev"
        sleep 2
    fi

    # Check and kill processes on specific ports (including common dev server ports)
    for port in 3000 3001 5173 8080; do
        if lsof -i :$port > /dev/null; then
            echo "Port $port is in use. Killing existing process..."
            kill $(lsof -ti :$port)
            sleep 1
        fi
    done
}

# Close specific terminal windows
close_dev_terminals() {
    # First kill any running dev processes
    pkill -f "bun dev"
    pkill -f "npm run dev"
    pkill -f "sst dev"
    
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
    pkill -f "bun dev"
    pkill -f "npm run dev"
    pkill -f "sst dev"
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

# Function to start dev servers
start_dev_servers() {
    local selected_projects=("$@")
    
    echo "Starting dev servers for selected projects..."
    
    # Start selected projects
    for project in "${selected_projects[@]}"; do
        case $project in
            "ui-memories")
                echo "Starting ui-memories..."
                window_id=$(osascript <<EOF
                    tell application "Terminal"
                        activate
                        set newWindow to do script "cd /Users/memories/Projects/memories-projects/memorials-platform-monorepo/ui-memories && bun dev"
                        return id of window 1
                    end tell
EOF
                )
                store_terminal_id "$window_id"
                ;;
            "memories-website")
                echo "Starting memories-website..."
                window_id=$(osascript <<EOF
                    tell application "Terminal"
                        activate
                        set newWindow to do script "cd /Users/memories/Projects/memories-projects/memories-website && aws-vault exec mem-dev -- bun sst dev"
                        return id of window 1
                    end tell
EOF
                )
                store_terminal_id "$window_id"
                ;;
            "memories")
                echo "Starting memories 2.0..."
                window_id=$(osascript <<EOF
                    tell application "Terminal"
                        activate
                        set newWindow to do script "cd /Users/memories/Projects/memories-projects/memories && docker-compose up -d postgres && aws-vault exec mem-dev -- bun sst dev --stage michael && aws-vault exec mem-dev -- bun db push --stage michael"
                        return id of window 1
                    end tell
EOF
                )
                store_terminal_id "$window_id"
                ;;
            "futuremefinance")
                echo "Starting futuremefinance..."
                window_id=$(osascript <<EOF
                    tell application "Terminal"
                        activate
                        set newWindow to do script "cd /Users/memories/Projects/memories-projects/futuremefinance && npm run dev"
                        return id of window 1
                    end tell
EOF
                )
                store_terminal_id "$window_id"
                ;;
        esac
    done
}

# Main script execution

# Main script loop
while true; do
    # Clear screen and show project selection menu
    clear
    echo -e "\nMemories Development Environment Setup"
    echo -e "====================================="
    
    echo -e "\nLaunch mode:"
    echo "1) Essential apps only"
    echo "2) All apps"
    read -p "Enter choice (1-2): " launch_mode

    # Project selection menu
    echo -e "\nSelect projects to start:"
    echo "1) ui-memories (localhost:3000)"
    echo "2) memories-website (localhost:3001)"
    echo "3) memories (localhost:3000)"
    echo "4) futuremefinance (localhost:8080)"
    echo "5) All projects"
    echo "6) No dev servers"
    read -p "Enter project choice(s) separated by spaces (e.g., 1 3 4): " project_choices

    # Parse project selections
    selected_projects=()
    if [[ " $project_choices " =~ " 5 " ]]; then
        selected_projects=("ui-memories" "memories-website" "memories" "futuremefinance")
    else
        for choice in $project_choices; do
            case $choice in
                1) selected_projects+=("ui-memories") ;;
                2) selected_projects+=("memories-website") ;;
                3) selected_projects+=("memories") ;;
                4) selected_projects+=("futuremefinance") ;;
            esac
        done
    fi

    read -p "Enter duration in minutes before auto-close [Press Enter for no auto-close]: " duration

    # Only proceed with timer if duration was provided
    if [ -n "$duration" ]; then
        duration_seconds=$(validate_duration "$duration")
        # Set initial end time using bc for calculation
        end_time=$(echo "$(date +%s) + $duration_seconds" | bc)
    fi

    # Open applications
    echo "Starting applications..."
    essential_apps=("Google Chrome" "Cursor" "Github Desktop" "Slack" "1Password" "Screenshot Monitor" "Docker Desktop" "Obsidian")
    all_apps=("Postman" "Notion" "Microsoft Outlook" "Microsoft Teams" "ChatGPT")
    if [ "$launch_mode" = "1" ]; then
        apps=("${essential_apps[@]}")
    else
        apps=("${all_apps[@]}" "${essential_apps[@]}")
    fi
    open_apps "${apps[@]}"

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
    else
        echo "No dev servers selected."
    fi

    # Open Chrome profiles with URLs based on selected projects
    echo "Starting Chrome with specified URLs..."
    profile_path="Profile 3"

    # Always open these URLs regardless of project selection
    common_urls=(
      "https://screenshotmonitor.com/myhome"
      "https://linear.app/memoriestech/team/MEM/cycle/active"
    )

    # Project-specific URLs
    project_urls=()
    for project in "${selected_projects[@]}"; do
        case $project in
            "ui-memories")
                project_urls+=("http://localhost:3000")
                ;;
            "memories-website")
                project_urls+=("http://localhost:3001")
                ;;
            "memories")
                project_urls+=("http://localhost:3000")
                ;;
            "futuremefinance")
                project_urls+=(
                    "http://localhost:8080"
                    "https://futuremefinance.lovable.app/"
                    "https://lovable.dev/projects/2c4b404d-f64c-403d-bebf-d86c66c28200"
                    "https://supabase.com/dashboard/project/shblrzvbqtaxcfgtpmfc"
                    "https://console.cloud.google.com/apis/credentials?authuser=1&inv=1&invt=Ab1xMA&project=futureme-finance"
                )
                ;;
        esac
    done

    # Additional URLs for all apps mode
    all_urls=()
    if [ "$launch_mode" = "2" ]; then
        all_urls=("https://ap-southeast-2.console.aws.amazon.com/console/home?region=ap-southeast-2")
    fi

    # Combine all URLs and open Chrome
    all_chrome_urls=("${common_urls[@]}" "${project_urls[@]}" "${all_urls[@]}")
    if [ ${#all_chrome_urls[@]} -gt 0 ]; then
        open_chrome "$profile_path" "${all_chrome_urls[@]}"
    fi

    # Start countdown and menu display with profile path and apps
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
        # Continue to next iteration of the loop (return to main menu)
        continue
    fi
    
    # If we reach here, the timer has finished or user chose to close
    # Ask if user wants to start a new session
    echo -e "\nSession ended. Would you like to start a new session?"
    echo "1) Start new session"
    echo "2) Exit"
    read -p "Enter choice (1-2): " restart_choice
    
    if [ "$restart_choice" = "2" ]; then
        echo "Goodbye!"
        exit 0
    fi
    # If choice is 1, continue to next iteration (return to main menu)
done