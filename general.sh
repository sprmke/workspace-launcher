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
    local profile_path=$1
    
    # Close Chrome windows // TODO: Close specific profile only
    osascript -e "tell application \"Google Chrome\" to quit"
    
    # Close other applications if provided
    shift
    for app in "$@"; do
        osascript -e "tell application \"$app\" to quit"
    done

    # Wait for the Chrome and applications to close
    sleep 5
}

# Function to open Chrome with specific profile and URLs in a single window
open_chrome() {
    echo "Starting Chrome with profile: $profile_path..."
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
            clear  # Clear screen before returning to main menu
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
                    clear  # Clear screen before returning to main menu
                    return
                    ;;
            esac
        fi
    done
}

# Main loop for category selection
while true; do
    echo "Select workspace:"
    echo "1) Condo"
    echo "2) Crypto"
    echo "3) Stock"
    echo "4) Study"
    echo "5) Budget"
    echo "6) -Exit-"
    read -p "Enter choice (1-6): " choice

    [ "$choice" = "6" ] && exit 0

    # Clear screen before showing launch mode menu
    clear
    echo -e "\nLaunch mode:"
    echo "1) Essential apps only"
    echo "2) All apps"
    read -p "Enter choice (1-2): " launch_mode
    
    # Get duration with default value of 30 minutes
    read -p "Enter duration in minutes before auto-close [30]: " duration
    duration=${duration:-30}  # Set default to 30 if empty
    duration_seconds=$(validate_duration "$duration")

    # Set initial end time using bc for calculation
    end_time=$(echo "$(date +%s) + $duration_seconds" | bc)

    # Store profile path and apps for the selected category
    profile_path=""
    apps=()
    essential_urls=()
    all_urls=()
    
    case $choice in
        1)  # Condo
            profile_path="Profile 12"
            # Essential URLs
            essential_urls=(
                "https://chatgpt.com/"
                "https://business.facebook.com/latest/inbox/all/"
                "https://business.facebook.com/latest/content_calendar"
                "https://docs.google.com/spreadsheets/d/1KE2_LJ-ydOSr2VhvkLrfMMGd66gPwvq5SLhG9KnuOQw"
            )
            # Essential apps
            essential_apps=("Messenger")
            # Additional apps
            all_apps=("Adobe Photoshop 2024" "Slack" "Microsoft Teams")
            
            # Open Chrome with appropriate URLs based on launch mode
            if [ "$launch_mode" = "1" ]; then
                open_chrome "$profile_path" "${essential_urls[@]}"
                apps=("${essential_apps[@]}")
            else
                open_chrome "$profile_path" "${essential_urls[@]}" "${all_urls[@]}"
                apps=("${essential_apps[@]}" "${all_apps[@]}")
            fi
            open_apps "${apps[@]}"
            ;;
        2)  # Crypto
            profile_path="Profile 15"
            # Essential URLs
            essential_urls=(
                "https://chatgpt.com/"
                "https://banterbubbles.com/"
                "https://www.okx.com/web3"
                "https://coinmarketcap.com/portfolio-tracker/"
                "https://www.binance.com/en/my/wallet/account/overview"
                "https://cointelegraph.com/category/latest-news"
                "https://www.youtube.com/"
            )
            # Additional URLs
            all_urls=(
                "https://cryptopanic.com/"
                "https://www.investagrams.com/News/"
                "https://www.todayonchain.com/"
                "https://www.okx.com/balance/finance"
                "https://www.bybit.com/user/assets/home/financial"
                "https://docs.google.com/spreadsheets/d/1btnGvfGDEqGIiOj_1pEoelv3PdyVG9lqpv_MZBy2m-M"
                "https://docs.google.com/spreadsheets/d/15vfj4cTNNCfgs5qnrAjbzCiv2zrBIFzAt2MkpV0jMCg"
            )
            # Essential apps
            # essential_apps=("Discord")
            # Additional apps
            all_apps=("Slack" "Microsoft Teams")

            # Open Chrome with appropriate URLs based on launch mode
            if [ "$launch_mode" = "1" ]; then
                open_chrome "$profile_path" "${essential_urls[@]}"
                apps=("${essential_apps[@]}")
            else
                open_chrome "$profile_path" "${essential_urls[@]}" "${all_urls[@]}"
                apps=("${essential_apps[@]}" "${all_apps[@]}")
            fi
            # Open second profile
            profile_path="Profile 1"
            open_chrome "$profile_path" "https://www.bitget.com/spot/BTCUSDT"
            open_apps "${apps[@]}"
            ;;
        3)  # Stock
            profile_path="Profile 16"
            open_chrome "$profile_path" \
                "https://chatgpt.com/" \
                "https://www.investagrams.com/Portfolio/PortfolioDashboard/" \
                "https://www.investagrams.com/News/" \
                "https://docs.google.com/spreadsheets/d/1jAXEv6Io8nByaktHgkr11VF44QFfyCdjIVsTF3BAbrk/edit?gid=1965420003#gid=1965420003" \
                "https://svr2.colfinancial.com/ape/FINAL2_STARTER/HOME/HOME.asp" \
                "https://trade.dragonfi.ph/" \
                "https://www.youtube.com/"
            ;;
        4)  # Study
            profile_path="Profile 7"
            # Essential URLs
            essential_urls=(
                "chrome-extension://chphlpgkkbolifaimnlloiipkdnihall/onetab.html"
                "https://pomofocus.io/app"
                "https://chatgpt.com/"
                "https://claude.ai/"
                "https://www.udemy.com/home/my-courses/learning/"
            )
            # Additional URLs
            all_urls=(
                "https://www.linkedin.com/messaging/"
                "https://www.youtube.com/"
            )
            # Essential apps
            essential_apps=("Cursor" "Notion")
            # Additional apps
            all_apps=("Slack" "Microsoft Teams")
            # Open Chrome with appropriate URLs based on launch mode
            if [ "$launch_mode" = "1" ]; then
                open_chrome "$profile_path" "${essential_urls[@]}"
                apps=("${essential_apps[@]}")
            else
                open_chrome "$profile_path" "${essential_urls[@]}" "${all_urls[@]}"
                apps=("${essential_apps[@]}" "${all_apps[@]}")
            fi
            open_apps "${apps[@]}"
            ;;
        5)  # Budget
            profile_path="Profile 1"
            open_chrome "$profile_path" \
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

    # Start countdown and menu display with profile path and apps
    display_countdown_and_menu "$profile_path" "${apps[@]}"
done