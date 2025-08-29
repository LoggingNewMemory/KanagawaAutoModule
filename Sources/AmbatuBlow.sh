#!/system/bin/sh

# Set the directory where modules are stored
MODULE_DIR="/data/adb/modules/"

# --- Root Access Check ---
# Abort if the script is not run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script requires root access. Please run it with 'su'."
  exit 1
fi

# --- Module Discovery ---
# Check if the modules directory exists
if [ ! -d "$MODULE_DIR" ]; then
  echo "⚠️ Module directory not found at $MODULE_DIR"
  echo "No modules to uninstall."
  exit 0
fi

# Change to the module directory
cd "$MODULE_DIR" || exit

# Get a list of all module IDs and names for display
echo "🔎 Scanning for installed modules..."
MODULE_INFO=""
MODULE_IDS=""
for d in */; do
  if [ -f "${d}module.prop" ]; then
    id=$(grep '^id=' "${d}module.prop" | cut -d'=' -f2)
    name=$(grep '^name=' "${d}module.prop" | cut -d'=' -f2)
    MODULE_INFO="${MODULE_INFO}\n  - ${name} (ID: ${id})"
    MODULE_IDS="${MODULE_IDS} ${id}"
  fi
done

# Trim leading whitespace from MODULE_IDS
MODULE_IDS=$(echo "$MODULE_IDS" | sed 's/^[ \t]*//')

# If no modules are found, exit
if [ -z "$MODULE_IDS" ]; then
  echo "✅ No modules found to uninstall."
  exit 0
fi

# --- User Confirmation with Volume Keys ---
echo "‼️ WARNING: This script will uninstall the following modules:"
echo "--------------------------------------------------------"
echo "$MODULE_INFO"
echo "\n--------------------------------------------------------"
echo "This action cannot be undone."
echo ""
echo "ACTION REQUIRED:"
echo "    Press Volume UP (+) to CONTINUE"
echo "    Press Volume DOWN (-) to ABORT"
echo ""
echo "Waiting for input..."

# Function to listen for key presses
get_key() {
  # The 'getevent' command reads raw input events. We filter for key presses.
  # The 'grep -m 1' ensures the command exits after the first match.
  key_event=$(getevent -l | grep -m 1 -E 'KEY_VOLUMEUP.*DOWN|KEY_VOLUMEDOWN.*DOWN')

  # Check which key was pressed
  if echo "$key_event" | grep -q "KEY_VOLUMEUP"; then
    echo "UP"
  elif echo "$key_event" | grep -q "KEY_VOLUMEDOWN"; then
    echo "DOWN"
  fi
}

# Capture the key press
USER_CHOICE=$(get_key)

# --- Uninstallation Process ---
if [ "$USER_CHOICE" = "UP" ]; then
  echo "\n✅ Volume UP detected. Starting uninstallation process..."
  for id in $MODULE_IDS; do
    echo "Uninstalling module: $id"
    # Use the 'ksud' command and redirect its output to /dev/null
    ksud module uninstall "$id" > /dev/null 2>&1
  done
  
  echo "\n✅ All modules have been uninstalled."
  echo "A reboot is required for changes to take full effect."

  # --- Reboot Prompt ---
  echo "\n--------------------------------------------------------"
  echo "ACTION REQUIRED:"
  echo "    Press Volume UP (+) to REBOOT NOW"
  echo "    Press Volume DOWN (-) to REBOOT LATER"
  echo "Waiting for input..."
  
  # Get the user's choice for rebooting
  REBOOT_CHOICE=$(get_key)

  if [ "$REBOOT_CHOICE" = "UP" ]; then
    echo "Rebooting now..."
    reboot
  else
    echo "👍 Please reboot manually later. Exiting script."
  fi

else
  echo "\n🛑 Volume DOWN or no input detected. Operation cancelled by user."
fi

exit 0
