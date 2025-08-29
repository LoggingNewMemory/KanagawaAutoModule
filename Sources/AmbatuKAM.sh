#!/system/bin/sh

# --- Root Access Check ---
# Abort if the script is not run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script requires root access. Please run it with 'su'."
  exit 1
fi

# The directory where your .zip module files are stored.
MODULES_DIR="Modules"

# --- Root Manager Detection ---
echo "🔎 Detecting root manager..."
if command -v magisk >/dev/null 2>&1; then
  ROOT_MANAGER_NAME="Magisk Based"
  ROOT_TOOL="magisk"
elif command -v ksud >/dev/null 2>&1; then
  ROOT_MANAGER_NAME="KernelSU Based"
  ROOT_TOOL="ksud"
elif command -v apd >/dev/null 2>&1; then
  ROOT_MANAGER_NAME="APatch"
  ROOT_TOOL="apd"
else
  echo "❌ Error: No supported root manager found (Magisk, KernelSU, or APatch)."
  exit 1
fi
echo "✅ Detected: $ROOT_MANAGER_NAME"

# --- Script Start ---

# Check if the Modules directory exists.
if [ ! -d "$MODULES_DIR" ]; then
  echo "❌ Error: Directory '$MODULES_DIR' not found!"
  echo "Please create a folder named 'Modules' and place your module zip files inside it."
  exit 1
fi

# Check if there are any .zip files to install.
if ! ls "$MODULES_DIR"/*.zip >/dev/null 2>&1; then
    echo "🤔 No .zip modules found in the '$MODULES_DIR' directory."
    exit 0
fi

echo "\n🚀 Starting $ROOT_MANAGER_NAME module installation..."
echo "----------------------------------------"

# Loop through each .zip file in the directory.
for module in "$MODULES_DIR"/*.zip; do
  if [ -f "$module" ]; then
    echo "Installing: $(basename "$module")"
    
    # Run the installation command for the detected root manager.
    # The script is already root, but su -c ensures the command runs in the correct context.
    su -c "$ROOT_TOOL module install '$module'"
    
    echo "----------------------------------------"
  fi
done

echo "✅ All modules have been processed successfully!"
echo ""
echo "Choose an option:"
echo "[Volume +] = Reboot Now"
echo "[Volume -] = Reboot Later"
echo "----------------------------------------"

# Wait for user input to reboot.
while true; do
  # Capture a single key press event. We look for 'DOWN' state to avoid double triggers.
  EVENT=$(getevent -lqc 1)
  
  if echo "$EVENT" | grep -q "KEY_VOLUMEUP.*DOWN"; then
    echo "Rebooting now... 👋"
    reboot
    break
  elif echo "$EVENT" | grep -q "KEY_VOLUMEDOWN.*DOWN"; then
    echo "Rebooting later. Exiting script. 👍"
    break
  fi
done

exit 0