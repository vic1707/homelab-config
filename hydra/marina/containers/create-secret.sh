#!/bin/sh

# Check if exactly one argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <secret_name>"
    exit 1
fi

# Assign the first argument to SECRET_NAME
SECRET_NAME="$1"

# Prompt for secret input
printf "Enter your secret: "
stty -echo  # Disable echoing of input
read -r SECRET_INPUT
stty echo   # Re-enable echoing
echo        # Print a newline for better readability

# Create the Podman secret
printf "%s" "$SECRET_INPUT" | podman secret create "$SECRET_NAME" -

# Clear the variable (optional for security)
unset SECRET_INPUT

echo "Secret '$SECRET_NAME' created successfully."
