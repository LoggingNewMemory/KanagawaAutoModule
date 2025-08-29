##########################################################################################
#
# Universal Module Installer Script v2.3
#
# This script properly installs modules by calling the native command-line
# installer for the detected root solution (Magisk, KernelSU, etc.). This ensures
# modules are correctly "registered" and persist after a reboot.
#
##########################################################################################

# The installer script will extract our module's files to $MODPATH.
# The zip files we want to install will be in "$MODPATH/Modules".
MODULES_TO_INSTALL_DIR="$MODPATH/Modules"

##########################################################################################
# Environment Detection & Variable Setup
##########################################################################################

# The module installation path is standard.
MODULES_BASE_PATH="/data/adb/modules"

# We need to find the correct BusyBox and the correct installer command.
ROOT_SOLUTION="unknown"
BUSYBOX=""
INSTALLER_CMD=""

ui_print " "
ui_print "🔍 Detecting root solution..."

if [ -f "/data/adb/magisk/busybox" ]; then
  ROOT_SOLUTION="Magisk"
  BUSYBOX="/data/adb/magisk/busybox"
  # Magisk's installer command
  INSTALLER_CMD="magisk --install-module"
  ui_print "- Magisk detected."
elif [ -f "/data/adb/ksu/bin/busybox" ]; then
  ROOT_SOLUTION="KernelSU"
  BUSYBOX="/data/adb/ksu/bin/busybox"
  # KernelSU's installer command (path corrected)
  INSTALLER_CMD="/data/adb/ksu/bin/ksud module install"
  ui_print "- KernelSU detected."
elif [ -f "/data/adb/ap/bin/busybox" ]; then
  ROOT_SOLUTION="APatch"
  BUSYBOX="/data/adb/ap/bin/busybox"
  # APatch may not have a dedicated CLI installer, add if available.
  # We will fall back to manual installation for now.
  ui_print "- APatch detected. (Using manual install)"
elif [ -f "/data/adb/suki/bin/busybox" ]; then
  ROOT_SOLUTION="SukiSU"
  BUSYBOX="/data/adb/suki/bin/busybox"
  # SukiSU may not have a dedicated CLI installer, add if available.
  # We will fall back to manual installation for now.
  ui_print "- SukiSU detected. (Using manual install)"
else
  abort "❌ BusyBox binary not found for any known root solution."
fi

if [ ! -x "$BUSYBOX" ]; then
  abort "❌ BusyBox not found or not executable at $BUSYBOX!"
fi

ui_print "  - BusyBox: $BUSYBOX"
ui_print " "

##########################################################################################
# Main Installation Logic
##########################################################################################

ui_print "⚙️ Starting installation of bundled modules..."
ui_print " "

if [ ! -d "$MODULES_TO_INSTALL_DIR" ] || [ -z "$($BUSYBOX ls -A "$MODULES_TO_INSTALL_DIR")" ]; then
  ui_print "🤔 No modules found in the 'Modules' directory. Nothing to do."
  exit 0
fi

# Loop through all zip files in the 'Modules' directory
for SUB_MODULE_ZIP in $MODULES_TO_INSTALL_DIR/*.zip; do

  if [ ! -f "$SUB_MODULE_ZIP" ]; then
    continue
  fi

  SUB_MODULE_NAME=$($BUSYBOX basename "$SUB_MODULE_ZIP")
  ui_print "********************************************************"
  ui_print "Installing: $SUB_MODULE_NAME"
  ui_print "********************************************************"

  if [ -n "$INSTALLER_CMD" ]; then
    # METHOD 1: Use the native installer command (Preferred)
    ui_print "- Using native installer: $ROOT_SOLUTION"
    # Execute the command. It will handle everything.
    $INSTALLER_CMD "$SUB_MODULE_ZIP"
    ui_print "- ✅ Done installing $SUB_MODULE_NAME."
  else
    # METHOD 2: Manual installation (Fallback for APatch, etc.)
    ui_print "- Using manual installation method..."
    # This is the old logic, which may not persist on reboot for some root solutions.
    SUB_TMPDIR=$($BUSYBOX mktemp -d)
    unzip -o "$SUB_MODULE_ZIP" -d $SUB_TMPDIR >/dev/null
    if [ ! -f "$SUB_TMPDIR/module.prop" ]; then
      ui_print "  - ⚠️ Warning: 'module.prop' not found. Skipping."
      $BUSYBOX rm -rf $SUB_TMPDIR
      continue
    fi
    SUB_MODID=$($BUSYBOX grep '^id=' "$SUB_TMPDIR/module.prop" | $BUSYBOX cut -d'=' -f2 | $BUSYBOX tr -d '\r\n')
    if [ -z "$SUB_MODID" ]; then
      ui_print "  - ⚠️ Warning: Could not read 'id'. Skipping."
      $BUSYBOX rm -rf $SUB_TMPDIR
      continue
    fi
    ui_print "- Module ID: $SUB_MODID"
    SUB_MODPATH="$MODULES_BASE_PATH/$SUB_MODID"
    $BUSYBOX rm -rf "$SUB_MODPATH"
    $BUSYBOX mkdir -p "$SUB_MODPATH"
    $BUSYBOX cp -a "$SUB_TMPDIR/." "$SUB_MODPATH"
    # Set permissions manually
    $BUSYBOX find $SUB_MODPATH -type d -exec chmod 0755 {} \;
    $BUSYBOX find $SUB_MODPATH -type f -exec chmod 0644 {} \;
    $BUSYBOX chown -R 0.0 $SUB_MODPATH
    $BUSYBOX chcon -R u:object_r:system_file:s0 $SUB_MODPATH
    $BUSYBOX rm -rf $SUB_TMPDIR
    ui_print "- ✅ Done installing $SUB_MODID."
  fi
  ui_print " "
done

ui_print "🎉 All bundled modules have been processed."
ui_print " "

# FIX: Create a skip_mount file to tell the installer that this meta-module
# does not need to be mounted or processed further. This prevents the
# "Failed to copy image" error on an empty module.
touch $MODPATH/skip_mount
