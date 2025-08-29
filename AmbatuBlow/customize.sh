#!/system/bin/sh
#
# AmbatuBlow Module - Kamikaze Module Wiper
#
# WARNING: This script removes ALL installed Magisk modules in /data/adb/modules,
# including itself. This action is irreversible.
#

# This module doesn't install any files, so we skip the default extraction.
SKIPUNZIP=1

#==========================================================================================
# Main Logic
#==========================================================================================

ui_print "**********************************"
ui_print "* WARNING: SELF-DESTRUCTIVE ACTION *"
ui_print "**********************************"
ui_print "This module will remove ALL Magisk"
ui_print "modules, INCLUDING ITSELF."
ui_print "This action is IRREVERSIBLE."
ui_print " "
ui_print "Proceeding in 3 seconds..."
sleep 3
ui_print " "

# --- Set Modules Path ---
MODULES_PATH="/data/adb/modules"
ui_print "- Target path: $MODULES_PATH"
ui_print " "
ui_print "Initiating full module wipe..."
ui_print "--------------------------------"

# --- Loop and Delete ALL Modules ---
if [ ! -d "$MODULES_PATH" ] || [ -z "$(ls -A "$MODULES_PATH")" ]; then
    ui_print "i No modules found. Nothing to do."
else
    # Iterate over each item in the modules directory and delete it
    for ITEM in $MODULES_PATH/*; do
        if [ -d "$ITEM" ]; then
            MOD_ID=$(basename "$ITEM")
            ui_print "x Obliterating module: $MOD_ID"
            # Recursively remove the directory with superuser privileges
            su -c "rm -rf '$ITEM'"
        fi
    done
fi

ui_print "--------------------------------"
ui_print "✔ All modules have been wiped."
ui_print "✔ This module has also been removed."
ui_print " "