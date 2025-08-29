#!/system/bin/sh
#
# KernelSU Multi-Module Installer
#
# This script will install all KernelSU modules located in the 'Modules'
# directory of this zip file.
#

# The installer script sources this file, providing the following
# variables and functions:
#
# Variables:
# - MODPATH (path): The path where your module files should be installed.
# - TMPDIR (path): A temporary directory for your files.
# - ZIPFILE (path): The path to your module's installation zip.
#
# Functions:
# - ui_print <msg>: Prints a message to the console.
# - abort <msg>: Aborts the installation with an error message.
#

# We handle all file operations ourselves.
SKIPUNZIP=1

# Define a temporary directory for our operations to keep things clean.
INSTALL_DIR="/data/local/tmp/multi_installer"

ui_print " "
ui_print "**********************************************"
ui_print "* KernelSU Multi-Module Installer         *"
ui_print "**********************************************"
ui_print " "

# --- Step 1: Verify KernelSU is the active root solution ---
ui_print "- Verifying KernelSU installation..."
if ! command -v ksud >/dev/null 2>&1; then
  abort "! KernelSU not found. This installer is for KernelSU only."
else
  ui_print "  > KernelSU detected."
fi
ui_print " "

# --- Step 2: Prepare the installation environment ---
ui_print "- Preparing environment..."
# Clean up any previous installation attempts and create a fresh directory.
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
if [ ! -d "$INSTALL_DIR" ]; then
  abort "! Failed to create temporary directory. Aborting."
fi

# Extract the modules from this installer zip to the temporary directory.
ui_print "- Extracting bundled modules..."
unzip -o "$ZIPFILE" 'Modules/*' -d "$INSTALL_DIR" >/dev/null
MODULES_DIR="$INSTALL_DIR/Modules"

if [ -z "$(ls -A "$MODULES_DIR"/*.zip 2>/dev/null)" ]; then
  abort "! No module zip files found in the 'Modules' folder. Nothing to install."
fi
ui_print " "

# --- Step 3: Loop through and install each module ---
ui_print "--- Starting Module Installation ---"
for module_zip in "$MODULES_DIR"/*.zip; do
  if [ ! -f "$module_zip" ]; then
    ui_print "! No modules found to install. Skipping."
    break
  fi

  MODULE_NAME=$(basename "$module_zip")
  ui_print " "
  ui_print "▶ Installing: $MODULE_NAME"

  # Use the ksud command to install the module.
  su -c "ksud module install '$module_zip'"
  
  ui_print "✔ Attempted installation for $MODULE_NAME"
done

# --- Step 4: Cleanup ---
ui_print " "
ui_print "--- Finalizing ---"
ui_print "- Cleaning up temporary files..."
rm -rf "$INSTALL_DIR"

ui_print " "
ui_print "**********************************************"
ui_print "* Installation Done             *"
ui_print "**********************************************"
ui_print "- Please reboot your device to apply changes."
ui_print " "
