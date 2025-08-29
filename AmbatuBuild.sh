#!/bin/bash

# Define the source and build directories
SOURCES_DIR="Sources"
BUILD_DIR="Build"

# --- Optional Telegram Integration ---
TELEGRAM_ENABLED=false
if [ -f "megumi.sh" ]; then
    source megumi.sh
    TELEGRAM_ENABLED=true
fi

# Create the build directory if it doesn't exist
mkdir -p "$BUILD_DIR"

# --- UI Functions ---
welcome() {
    clear
    echo "---------------------------------"
    echo "           AmbatuBuild           "
    echo "---------------------------------"
    echo ""
}

success() {
    echo "---------------------------------"
    echo "    Build Process Completed      "
    printf "      Build Time: %s seconds\n" "$SECONDS"
    echo "---------------------------------"
}

# --- Telegram Functions ---
# Function to send file to Telegram
send_to_telegram() {
    local file_path="$1"
    local caption="$2"
    local chat_id="$3"

    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        echo "Error: TELEGRAM_BOT_TOKEN is not set in megumi.sh!"
        return 1
    fi
    if [ -z "$chat_id" ]; then
        echo "Error: Chat ID is empty!"
        return 1
    fi

    echo "Uploading $(basename "$file_path") to chat ID: $chat_id..."
    response=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
        -F "chat_id=$chat_id" \
        -F "document=@$file_path" \
        -F "caption=$caption")

    if echo "$response" | grep -q '"ok":true'; then
        echo "✓ Successfully uploaded to $chat_id"
        return 0
    else
        echo "✗ Failed to upload to $chat_id"
        echo "Response: $response"
        return 1
    fi
}

# Function to send message to Telegram
send_message_to_telegram() {
    local message="$1"
    local chat_id="$2"

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$chat_id" ]; then
        return 1
    fi

    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d "chat_id=$chat_id" \
        -d "text=$message" \
        -d "parse_mode=Markdown" > /dev/null
}

# Function to display available groups and get selection
select_telegram_groups() {
    local available_groups=()
    local group_names=()

    if [ ${#TELEGRAM_GROUPS[@]} -eq 0 ]; then
        echo "No Telegram groups configured in megumi.sh"
        return 1
    fi

    echo ""
    echo "Available Telegram groups:"
    echo "--------------------------"
    local index=1
    for group in "${TELEGRAM_GROUPS[@]}"; do
        local group_name=$(echo "$group" | cut -d':' -f1)
        local chat_id=$(echo "$group" | cut -d':' -f2)
        available_groups+=("$chat_id")
        group_names+=("$group_name")
        echo "$index. $group_name"
        ((index++))
    done
    echo "a. All groups"
    echo "0. Cancel"
    echo ""

    while true; do
        read -p "Select groups (e.g., 1,3 or 'a' for all): " selection
        selection=${selection,,} 

        if [[ "$selection" == "0" ]]; then
            return 1
        elif [[ "$selection" == "a" || "$selection" == "all" ]]; then
            SELECTED_GROUPS=("${available_groups[@]}")
            SELECTED_GROUP_NAMES=("${group_names[@]}")
            return 0
        else
            SELECTED_GROUPS=()
            SELECTED_GROUP_NAMES=()
            IFS=',' read -ra SELECTIONS <<< "$selection"
            local valid=true
            for sel in "${SELECTIONS[@]}"; do
                sel=$(echo "$sel" | tr -d '[:space:]') 
                if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#available_groups[@]} ]; then
                    local idx=$((sel-1))
                    SELECTED_GROUPS+=("${available_groups[$idx]}")
                    SELECTED_GROUP_NAMES+=("${group_names[$idx]}")
                else
                    echo "Invalid selection: $sel"
                    valid=false
                    break
                fi
            done
            if [ "$valid" = true ] && [ ${#SELECTED_GROUPS[@]} -gt 0 ]; then
                return 0
            fi
        fi
        echo "Please enter valid selections."
    done
}

# Function to prompt for changelog
prompt_changelog() {
    echo ""
    read -p "Add a changelog? (Y/N): " ADD_CHANGELOG
    if [[ "${ADD_CHANGELOG,,}" == "y" || "${ADD_CHANGELOG,,}" == "yes" ]]; then
        echo ""
        echo "Enter changelog (press Ctrl+D when finished):"
        echo "---"
        CHANGELOG=$(cat)
        echo "---"
        if [ -n "$CHANGELOG" ]; then
            echo "Changelog captured."
            return 0
        else
            echo "No changelog entered."
            return 1
        fi
    fi
    return 1
}

# --- Main Build Logic ---
build_project() {
    rm -rf "$BUILD_DIR"/*

    # Set a fixed project name
    PROJECT_NAME="AmbatuKAM"

    # Get user input for naming the zip file
    read -p "Enter Version (e.g., V1.0): " VERSION
    while true; do
        read -p "Enter Build Type (LAB/RELEASE): " BUILD_TYPE
        BUILD_TYPE=${BUILD_TYPE^^}
        if [[ "$BUILD_TYPE" == "LAB" || "$BUILD_TYPE" == "RELEASE" ]]; then
            break
        fi
        echo "Invalid input. Please enter LAB or RELEASE."
    done

    # Navigate into the sources directory
    cd "$SOURCES_DIR" || { echo "Error: '$SOURCES_DIR' directory not found!"; exit 1; }

    # Create the zip file without modifying any source files
    ZIP_NAME="${PROJECT_NAME}-${VERSION}-${BUILD_TYPE}.zip"
    ZIP_PATH="../$BUILD_DIR/$ZIP_NAME"
    echo "Creating archive: $ZIP_NAME"
    zip -q -r "$ZIP_PATH" ./*
    
    cd ..
    echo "Successfully created: $BUILD_DIR/$ZIP_NAME"

    # --- Post-build Telegram actions ---
    if [ "$TELEGRAM_ENABLED" = true ]; then
        read -p "Post to Telegram groups? (y/N): " POST_TO_TELEGRAM
        if [[ "${POST_TO_TELEGRAM,,}" == "y" || "${POST_TO_TELEGRAM,,}" == "yes" ]]; then
            HAS_CHANGELOG=false
            if prompt_changelog; then
                HAS_CHANGELOG=true
            fi

            if select_telegram_groups; then
                echo ""
                echo "Preparing to upload to selected Telegram groups..."

                # URL-encode the message for the Telegram API
                local message
                message+="🚀 *New Build Available!*%0A%0A"
                message+="📦 *Project:* $PROJECT_NAME%0A"
                message+="🏷️ *Version:* $VERSION%0A"
                message+="🔧 *Build Type:* $BUILD_TYPE%0A"

                if [ "$HAS_CHANGELOG" = true ] && [ -n "$CHANGELOG" ]; then
                    ENCODED_CHANGELOG=$(printf '%s' "$CHANGELOG" | jq -s -R -r @uri)
                    message+="%0A📝 *Changelog:*%0A$ENCODED_CHANGELOG"
                fi
                
                for i in "${!SELECTED_GROUPS[@]}"; do
                    local chat_id="${SELECTED_GROUPS[$i]}"
                    local group_name="${SELECTED_GROUP_NAMES[$i]}"
                    echo ""
                    echo "📤 Posting to: $group_name"
                    send_message_to_telegram "$message" "$chat_id"
                    send_to_telegram "$BUILD_DIR/$ZIP_NAME" "📱 $PROJECT_NAME - $VERSION ($BUILD_TYPE)" "$chat_id"
                done
            else
                echo "Telegram upload cancelled."
            fi
        fi
    fi
}

# --- Main Execution ---
welcome
SECONDS=0  # Start timing
build_project
success