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
    local profile_path=$1
    
    # Close Chrome windows // TODO: Close specific profile only
    osascript -e "tell application \"Google Chrome\" to quit"
    
    # Close other applications if provided
    shift
    for app in "$@"; do
        osascript -e "tell application \"$app\" to quit"
    done
}

# Function to open Chrome with specific profile and URLs in a single window
open_chrome() {
    echo "Starting Chrome with specified URLs..."
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
    echo "Starting applications..."
    for app in "$@"; do
        osascript -e "tell application \"$app\" to activate"
    done
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

# Main loop for category selection
while true; do
    clear
    echo "Select workspace:"
    echo "1) Condo"
    echo "2) Crypto"
    echo "3) Stock"
    echo "4) Study"
    echo "5) Budget"
    echo "6) -Exit-"
    read -p "Enter choice (1-6): " choice

    [ "$choice" = "6" ] && exit 0

    # Get duration with default value of 30 minutes
    read -p "Enter duration in minutes before auto-close [30]: " duration
    duration=${duration:-30}  # Set default to 30 if empty
    duration=$(validate_duration "$duration")

    # Store profile path and apps for the selected category
    profile_path=""
    apps=()
    
    case $choice in
        1)  # Condo
            profile_path="Profile 12"
            open_chrome "$profile_path" \
                "https://pomofocus.io/app" \
                "https://business.facebook.com/latest/inbox/all/" \
                "https://business.facebook.com/latest/content_calendar" \
                "https://docs.google.com/spreadsheets/d/1KE2_LJ-ydOSr2VhvkLrfMMGd66gPwvq5SLhG9KnuOQw"
            ;;
        2)  # Crypto
            profile_path="Profile 15"
            open_chrome "$profile_path" \
                "https://pomofocus.io/app" \
                "https://coinmarketcap.com/portfolio-tracker/" \
                "https://www.investagrams.com/News/" \
                "https://cryptopanic.com/" \
                "https://www.todayonchain.com/" \
                "https://cointelegraph.com/category/latest-news" \
                "https://www.bitget.com/spot/BTCUSDT" \
                "https://www.binance.com/en/my/wallet/account/overview" \
                "https://www.okx.com/balance/finance" \
                "https://www.bybit.com/user/assets/home/financial" \
                "https://www.youtube.com/" \
                "https://docs.google.com/spreadsheets/d/1btnGvfGDEqGIiOj_1pEoelv3PdyVG9lqpv_MZBy2m-M" \
                "https://docs.google.com/spreadsheets/d/15vfj4cTNNCfgs5qnrAjbzCiv2zrBIFzAt2MkpV0jMCg"
            profile_path="Profile 1"
            open_chrome "$profile_path" \
                "https://www.bitget.com/spot/BTCUSDT"
            ;;
        3)  # Stock
            profile_path="Profile 16"
            open_chrome "$profile_path" \
                "https://pomofocus.io/app" \
                "https://www.investagrams.com/Portfolio/PortfolioDashboard/" \
                "https://www.investagrams.com/News/" \
                "https://svr2.colfinancial.com/ape/FINAL2_STARTER/HOME/HOME.asp" \
                "https://www.youtube.com/" \
                "https://docs.google.com/spreadsheets/d/1jAXEv6Io8nByaktHgkr11VF44QFfyCdjIVsTF3BAbrk/edit?gid=1965420003#gid=1965420003"
            ;;
        4)  # Study
            profile_path="Profile 7"
            apps=("Cursor" "Visual Studio Code" "Notion")
            open_chrome "$profile_path" \
                "https://pomofocus.io/app" \
                "chrome-extension://chphlpgkkbolifaimnlloiipkdnihall/onetab.html" \
                "https://www.linkedin.com/messaging/" \
                "https://www.udemy.com/home/my-courses/learning/" \
                "https://www.youtube.com/"
            open_apps "${apps[@]}"
            ;;
        5)  # Budget
            profile_path="Profile 1"
            open_chrome "$profile_path" \
                "https://pomofocus.io/app" \
                "https://docs.google.com/spreadsheets/d/18_xpANJbYqf53RStc-x9bROy1Xjm04KB1s60yjOgF0E" \
                "https://docs.google.com/spreadsheets/d/19H2ixczbupOp1O91Nh3IRRl-X2iVOSei50b1VtZugBw" \
                "https://docs.google.com/spreadsheets/d/1VHLSZxaTcm7IKI16Wkz_PDw6S7ZQsohRGap15EhfjzM" \
                "https://docs.google.com/spreadsheets/d/1H7oUwjkkPbMS29k31VlQ90pm9uQaGe1EzHFfawPvtFM"
            ;;
        *)
            echo "Invalid choice"
            continue
            ;;
    esac

    # Set initial end time
    end_time=$(($(date +%s) + duration * 60))

    # Start countdown and menu display with profile path and apps
    display_countdown_and_menu "$profile_path" "${apps[@]}"
done