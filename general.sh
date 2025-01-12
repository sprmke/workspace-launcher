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
        "$first_url" &
    
    # Wait a bit for the window to open
    sleep 2
    
    # Open remaining URLs in new tabs in the same window
    for url in "$@"; do
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
            --profile-directory="$profile_path" \
            --new-tab \
            "$url"
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
    # Initial display of menu options (only once)
    echo -e "\nTimer Control Menu:"
    echo "1) Extend duration"
    echo "2) Close now"
    echo -e "\nTime remaining: calculating..."
    
    while true; do
        current_time=$(date +%s)
        remaining_seconds=$((end_time - current_time))
        
        if [ $remaining_seconds -le 0 ]; then
            echo -e "\nTime's up! Returning to category selection..."
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
                    read -p "Enter additional minutes: " extra_duration
                    new_duration=$(( (end_time - $(date +%s)) / 60 + extra_duration ))
                    end_time=$(($(date +%s) + new_duration * 60))
                    ;;
                2)
                    echo -e "\nReturning to category selection..."
                    return
                    ;;
            esac
        fi
    done
}

# Main loop for category selection
while true; do
    clear
    echo "Select category:"
    echo "1) Condo"
    echo "2) Crypto"
    echo "3) Stock"
    echo "4) Study"
    echo "5) Budget"
    echo "6) -Exit-"
    read -p "Enter choice (1-6): " choice

    [ "$choice" = "6" ] && exit 0

    # Get duration
    read -p "Enter duration in minutes before auto-close: " duration

    case $choice in
        1)  # Condo
            open_chrome "Profile 12" \
                "https://pomofocus.io/app" \
                "https://business.facebook.com/latest/inbox/all/" \
                "https://business.facebook.com/latest/content_calendar" \
                "https://docs.google.com/spreadsheets/d/1KE2_LJ-ydOSr2VhvkLrfMMGd66gPwvq5SLhG9KnuOQw"
            ;;
        2)  # Crypto
            open_chrome "Profile 15" \
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
            ;;
        3)  # Stock
            open_chrome "Profile 16" \
                "https://pomofocus.io/app" \
                "https://www.investagrams.com/Portfolio/PortfolioDashboard/" \
                "https://www.investagrams.com/News/" \
                "https://svr2.colfinancial.com/ape/FINAL2_STARTER/HOME/HOME.asp" \
                "https://www.youtube.com/" \
                "https://docs.google.com/spreadsheets/d/1jAXEv6Io8nByaktHgkr11VF44QFfyCdjIVsTF3BAbrk/edit?gid=1965420003#gid=1965420003"
            ;;
        4)  # Study
            open_chrome "Profile 7" \
                "https://pomofocus.io/app" \
                "chrome-extension://chphlpgkkbolifaimnlloiipkdnihall/onetab.html" \
                "https://www.linkedin.com/messaging/" \
                "https://www.udemy.com/home/my-courses/learning/" \
                "https://www.youtube.com/"
            open_apps "Cursor" "Visual Studio Code" "Notion"
            ;;
        5)  # Budget
            open_chrome "Profile 1" \
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

    # Start countdown and menu display
    display_countdown_and_menu
done