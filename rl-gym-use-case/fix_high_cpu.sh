#!/bin/bash

# Script to apply patch with git workflow
# Usage: ./apply-patch.sh [branch-name] [commit-message]

# Set default values
BRANCH_NAME=${1:-"fix/high-cpu-$(date +%Y%m%d-%H%M%S)"}
COMMIT_MESSAGE=${2:-"fix: high cpu usage"}
PATCH_FILE=${3:-"high_cpu_usage.patch"}

echo "Starting patch application workflow..."
echo "Branch name: $BRANCH_NAME"
echo "Commit message: $COMMIT_MESSAGE"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Check if patch file exists
if [ ! -f "$PATCH_FILE" ]; then
    echo "Error: $PATCH_FILE file not found"
    exit 1
fi

# 1. Create and checkout new branch
echo "Creating new branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create branch"
    exit 1
fi

# 2. Apply the patch
echo "Applying patch..."
git apply "$PATCH_FILE"

if [ $? -ne 0 ]; then
    echo "Error: Failed to apply patch"
    echo "Cleaning up - switching back to previous branch"
    git checkout -
    git branch -D "$BRANCH_NAME"
    exit 1
fi

# 3. Add changes and commit
echo "Adding changes and committing..."
git add src/controllers/dataProcessingJob.ts

git commit -m "$COMMIT_MESSAGE"

if [ $? -ne 0 ]; then
    echo "Error: Failed to commit changes"
    echo "Cleaning up - switching back to previous branch"
    git checkout -
    git branch -D "$BRANCH_NAME"
    exit 1
fi

# 4. Push to remote
echo "Pushing to remote repository..."
git push -u origin "$BRANCH_NAME"

if [ $? -ne 0 ]; then
    echo "Warning: Failed to push to remote"
    echo "Changes are committed locally on branch: $BRANCH_NAME"
    echo "You can try pushing manually later with: git push -u origin $BRANCH_NAME"
    exit 1
fi

echo "Success! Patch applied and pushed to branch: $BRANCH_NAME"
echo "You can now create a pull request or merge the changes as needed."

# 5. Go back to previous branch
echo "Going back to previous branch..."
git checkout -

echo "Done!"