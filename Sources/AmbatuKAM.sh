#!/system/bin/sh

# The directory where your .zip module files are stored.
MODULES_DIR="Modules"

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

echo "🚀 Starting KernelSU module installation..."
echo "----------------------------------------"

# Loop through each .zip file in the directory.
for module in "$MODULES_DIR"/*.zip; do
  if [ -f "$module" ]; then
    echo "Installing: $(basename "$module")"
    
    # Run the installation command with root privileges.
    su -c "ksud module install '$module'"
    
    echo "----------------------------------------"
  fi
done

echo "✅ All modules have been processed successfully!"
