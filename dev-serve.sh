#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="jekyll-dev"

# Cleanup function to remove the image
cleanup() {
    if [ $? -ne 0 ]; then
        echo ""
    fi
    
    echo ""
    echo -e "${YELLOW}Do you want to remove the Docker image? (y/n)${NC}"
    echo "Press 'y' to remove, 'n' to keep, if no response the image will be removed in 10 seconds..."
    
    # Use read with timeout (10 seconds)
    response=""
    read -t 10 -n 1 response
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        echo ""
        echo -e "${YELLOW}Removing Docker image...${NC}"
        podman rmi -f "${IMAGE_NAME}" &>/dev/null || true
        echo -e "${GREEN}Cleanup complete${NC}"
    elif [ "$response" = "n" ] || [ "$response" = "N" ]; then
        echo ""
        echo -e "${GREEN}Skipping cleanup. Image kept for future use.${NC}"
    else
        echo ""
        echo -e "${YELLOW}No response. Removing Docker image...${NC}"
        podman rmi -f "${IMAGE_NAME}" &>/dev/null || true
        echo -e "${GREEN}Cleanup complete${NC}"
    fi
}

# Set trap to run cleanup on EXIT, INT (Ctrl+C), and TERM signals
trap cleanup EXIT INT TERM

echo -e "${YELLOW}Jekyll Development Server${NC}"
echo ""

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: podman is not installed or not in PATH${NC}"
    echo "Please install podman from: https://podman.io/docs/installation"
    exit 1
fi

echo -e "${GREEN}podman found${NC}"

echo ""
echo -e "${YELLOW}Building Jekyll dev image...${NC}"
podman build -f "${SCRIPT_DIR}/Dockerfile.dev" -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

echo ""
echo -e "${GREEN}Image built successfully${NC}"
echo ""
echo -e "${YELLOW}Starting Jekyll development server...${NC}"
echo -e "${YELLOW}Server will be available at: http://localhost:9000${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""

# Run the Jekyll development server
podman run \
    --rm \
    -it \
    -v "${SCRIPT_DIR}/app:/app:Z" \
    -p 9000:9000 \
    "${IMAGE_NAME}" \
    jekyll serve \
    --host 0.0.0.0 \
    --port 9000 \
    --incremental \
    --config /app/_config.yml \
    --source /app 2>&1 | grep -v "fatal: not a git repository\|Stopping at filesystem boundary"
