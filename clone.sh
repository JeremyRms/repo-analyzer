#!/bin/bash

# Set default organization name and prompt to override
ORG_NAME="AlphaFounders"
read -p "Enter GitHub organization name [$ORG_NAME]: " input
ORG_NAME=${input:-$ORG_NAME}

# Prompt for destination folder
read -p "Enter destination folder path: " DEST_FOLDER

# Create destination folder if it doesn't exist
mkdir -p "$DEST_FOLDER"
cd "$DEST_FOLDER"

# Check if GitHub CLI (gh) is installed
if ! command -v gh &>/dev/null; then
    echo "GitHub CLI (gh) is not installed. Please install it first."
    exit 1
fi

# Check if user is authenticated with GitHub
if ! gh auth status &>/dev/null; then
    echo "Please authenticate with GitHub first using 'gh auth login'"
    exit 1
fi

# Get all non-archived repositories for the organization
echo "Fetching repositories from $ORG_NAME..."
REPOS=$(gh repo list "$ORG_NAME" \
    --no-archived \
    --visibility private \
    --source \
    --limit 1000 \
    --json "name,languages" \
    --jq '.[] | 
    select(.languages != []) |
    select(
        .languages | 
        sort_by(.size) | 
        reverse | 
        .[0].node.name == "Go"
    ) | 
    .name')

# Debug output
echo "DEBUG: Showing all repos and their primary languages:"
gh repo list "$ORG_NAME" \
    --no-archived \
    --visibility private \
    --source \
    --limit 1000 \
    --json "name,languages" \
    --jq '.[] | select(.languages != []) | 
    "\(.name): Primary language is \(.languages | sort_by(.size) | reverse | .[0].node.name)"'

if [ -z "$REPOS" ]; then
    echo "No Go repositories found in $ORG_NAME"
    exit 0
fi

# Clone each repository
for REPO in $REPOS; do
    echo "Processing $REPO..."
    if [ -d "$REPO" ]; then
        echo "Repository already exists, updating..."
        cd "$REPO"

        # Determine default branch (main or master)
        DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)

        # Fetch, checkout default branch, and reset to origin
        git fetch origin
        git checkout "$DEFAULT_BRANCH"
        git reset --hard "origin/$DEFAULT_BRANCH"
        cd ..
    else
        echo "Cloning $REPO..."
        git clone --depth 1 "https://github.com/$ORG_NAME/$REPO.git"
    fi
done

echo "Done! All Go repositories have been cloned to $DEST_FOLDER"
