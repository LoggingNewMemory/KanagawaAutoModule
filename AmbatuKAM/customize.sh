#!/system/bin/sh
#
# Universal Multi-Module Installer
#
# This script will install all Magisk/KernelSU modules located in the 'Modules'
# directory of this zip file. It automatically detects the current root
# solution (Magisk, KernelSU Next, SukiSU) and uses the appropriate
# command-line installer.
#

# The Magisk module installer script sources this file, providing the following
# variables and functions:
#
# Variables:
# - MAGISK_VER (string): The version string of the installed Magisk.
# - MAGISK_VER_CODE (int): The version code of the installed Magisk.
# - BOOTMODE (bool): true if the module is being installed in the Magisk app.
# - MODPATH (path): The path where your module files should be installed.
# - TMPDIR (path): A temporary directory for your files.
# - ZIPFILE (path): The path to your module's installation zip.
# - ARCH (string): The device's CPU architecture.
# - IS64BIT (bool): true if the architecture is 64-bit.
# - API (int): The Android API level of the device.
#
# Functions:
# - ui_print <msg>: Prints a message to the console.
# - abort <msg>: Aborts the installation with an error message.
#

# It's good practice to set this, so the module installer script doesn't
# try to extract the main module files. We handle everything ourselves.
SKIPUNZIP=1

# Define a temporary directory for our operations to keep things clean.
INSTALL_DIR="/data/local/tmp/multi_installer"

ui_print " "
ui_print "**********************************************"
ui_print "* Universal Multi-Module Installer      *"
ui_print "**********************************************"
ui_print " "

# --- Step 1: Detect the active root solution ---
ROOT_SOLUTION="unknown"
ui_print "- Detecting root solution..."
if command -v magisk >/dev/null 2>&1; then
  # Magisk provides the 'magisk' command.
  ROOT_SOLUTION="magisk"
  ui_print "  > Magisk detected."
elif command -v ksud >/dev/null 2>&1; then
  ROOT_SOLUTION="kernelsu_next"
  ui_print "  > KernelSU Next detected."
elif command -v sukisud >/dev/null 2>&1; then # Assumption for SukiSU
  ROOT_SOLUTION="sukisu"
  ui_print "  > SukiSU detected."
else
  abort "! No supported root solution (Magisk, KernelSU Next, SukiSU) found. Aborting."
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

  case $ROOT_SOLUTION in
    "magisk")
      # Use Magisk's command-line module installer.
      magisk --install-module "$module_zip"
      ;;
    "kernelsu_next")
      # Use the ksud command as specified.
      su -c ksud module install "$module_zip"
      ;;
    "sukisu")
      # Assuming SukiSU uses a similar command structure to KernelSU.
      su -c sukisud module install "$module_zip"
      ;;
  esac

  # It's difficult to robustly check for installation success from the CLI output,
  # but we can at least confirm the command was attempted.
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