#!/bin/bash
read -p "Enter the size of the swap file in GB: " SIZE_GB
if ! [[ "$SIZE_GB" =~ ^[0-9]+$ ]] || [ "$SIZE_GB" -le 0 ]; then
    echo "Invalid input"
    exit 1
fi

FOLDER_TO_CREATE=""
SIZE_MB=$((SIZE_GB * 1024))
sudo dd if=/dev/zero of="$FOLDER_TO_CREATE"/swap"${SIZE_GB}"GB count=1K bs="${SIZE_MB}"M
sudo mkswap "$FOLDER_TO_CREATE"/swap"${SIZE_GB}"GB
sudo chown root:root "$FOLDER_TO_CREATE"/swap"${SIZE_GB}"GB
sudo chmod 600 "$FOLDER_TO_CREATE"/swap"${SIZE_GB}"GB
sudo swapon "$FOLDER_TO_CREATE"/swap"${SIZE_GB}"GB
echo "Swap file of ${SIZE_GB} GB created and activated successfully."
