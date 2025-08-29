#!/system/bin/sh
#
# AmbatuBlow Module - Kamikaze KernelSU Module Wiper
#
# WARNING: This script uninstalls ALL installed KernelSU modules,
# including itself. This action is irreversible.
#

# This module doesn't install any files, so we skip the default extraction.
SKIPUNZIP=1

#==========================================================================================
# Functions
#==========================================================================================

# Function to detect volume key press
# Returns 0 for Volume UP, 1 for Volume DOWN
get_key_press() {
  ui_print "- Waiting for confirmation..."
  while true; do
    # getevent arguments:
    # -l: show event labels (e.g., KEY_VOLUMEUP)
    # -q: run in quiet mode (no device info)
    # -c 1: read only one event then exit
    KEY_EVENT=$(getevent -lqc 1 2>&1)
    
    # Check if the captured event is a Volume UP press
    if echo "$KEY_EVENT" | grep -q "KEY_VOLUMEUP.*DOWN"; then
      return 0 # Return 0 for YES
    # Check if the captured event is a Volume DOWN press
    elif echo "$KEY_EVENT" | grep -q "KEY_VOLUMEDOWN.*DOWN"; then
      return 1 # Return 1 for NO
    fi
  done
}

#==========================================================================================
# Main Logic
#==========================================================================================

# --- Pre-flight Check ---
# Ensure ksud command exists before doing anything else.
if ! command -v ksud >/dev/null 2>&1; then
  abort "! This script is for KernelSU only. 'ksud' command not found."
fi

ui_print "**********************************"
ui_print "* WARNING: SELF-DESTRUCTIVE ACTION *"
ui_print "**********************************"
ui_print "This module will uninstall ALL"
ui_print "KernelSU modules, INCLUDING ITSELF."
ui_print "This action is IRREVERSIBLE."
ui_print " "
ui_print "- Press Volume UP to CONFIRM."
ui_print "- Press Volume DOWN to CANCEL."
ui_print " "

# Wait for the user to press a volume key
get_key_press

# Check the return code of the function ($? holds the last command's exit status)
# If get_key_press returned 0 (Volume UP), then proceed.
if [ "$?" -eq "0" ]; then
  ui_print "✔ Confirmed. Proceeding..."
  ui_print " "

  # --- Set Modules Path ---
  MODULES_PATH="/data/adb/modules"
  ui_print "- Target path: $MODULES_PATH"
  ui_print " "
  ui_print "Initiating KernelSU module uninstall..."
  ui_print "--------------------------------"

  # --- Loop and Process ALL Modules ---
  if [ ! -d "$MODULES_PATH" ] || [ -z "$(ls -A "$MODULES_PATH")" ]; then
      ui_print "i No modules found. Nothing to do."
  else
      # Iterate over each item in the modules directory
      for ITEM in $MODULES_PATH/*; do
          if [ -d "$ITEM" ]; then
              # --- KernelSU Uninstall Logic ---
              if [ -f "$ITEM/module.prop" ]; then
                  # Extract the module ID from module.prop
                  # Use sed for a more robust extraction of the id value
                  MOD_ID=$(sed -n 's/^id[[:space:]]*=[[:space:]]*//p' "$ITEM/module.prop")
                  if [ -n "$MOD_ID" ]; then
                      ui_print "-> Uninstalling module: $MOD_ID"
                      # Use the ksud command to uninstall the module
                      su -c "ksud module uninstall '$MOD_ID'"
                  else
                      ui_print "! Could not find ID in module.prop for $(basename "$ITEM")"
                  fi
              else
                  ui_print "! module.prop not found for $(basename "$ITEM"), skipping."
              fi
          fi
      done
  fi

  ui_print "--------------------------------"
  ui_print "✔ All modules have been processed."
  ui_print "✔ This module has also been processed."
  ui_print " "
  ui_print "i PLEASE REBOOT YOUR DEVICE to"
  ui_print "i complete the uninstallation."
  ui_print " "
else
  # If get_key_press returned 1 (Volume DOWN), then abort.
  ui_print "x Operation cancelled by user."
  abort "Aborted!"
fi
