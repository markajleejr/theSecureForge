# PowerShell Script for Windows

# Set variables for paths and repository
$sourcePath = "C:\Users\marka\Documents\Mark's Vault\posts"
$destinationPath = "C:\Users\marka\Documents\theSecureForge\content\posts"
$hugoConfigPath = "C:\Users\marka\Documents\theSecureForge\Hugo.toml"
$myrepo = "theSecureForge"

# Set error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Change to the script's directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

# Check for required commands
$requiredCommands = @('git', 'hugo')

foreach ($cmd in $requiredCommands) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd is not installed or not in PATH."
        exit 1
    }
}

# Function to update baseURL in Hugo.toml
function Update-BaseURL {
    param (
        [string]$newBaseURL
    )
    if (-not (Test-Path $hugoConfigPath)) {
        Write-Error "Hugo configuration file not found: $hugoConfigPath"
        exit 1
    }

    $configContent = Get-Content $hugoConfigPath
    $updatedContent = $configContent -replace '^baseURL\s*=\s*".*"$', "baseURL = `"$newBaseURL`""
    Set-Content -Path $hugoConfigPath -Value $updatedContent
}

# Extract the current baseURL from Hugo.toml
if (-not (Test-Path $hugoConfigPath)) {
    Write-Error "Hugo configuration file not found: $hugoConfigPath"
    exit 1
}

# Read and join the Hugo configuration content
$configContent = (Get-Content $hugoConfigPath -Raw)
Write-Host "Hugo config content: $configContent"

# Use regex to match the baseURL
if ($configContent -match 'baseURL\s*=\s*["''](.*?)["'']') {
    $originalBaseURL = $matches[1]
    Write-Host "Original baseURL extracted: $originalBaseURL"
} else {
    Write-Error "Could not extract baseURL from Hugo config file. Ensure it is properly defined."
    $originalBaseURL = "/"
}



# Step 1: Check if Git is initialized, and initialize if necessary
if (-not (Test-Path ".git")) {
    Write-Host "Initializing Git repository..."
    git init
    git remote add origin $myrepo
} else {
    Write-Host "Git repository already initialized."
    $remotes = git remote
    if (-not ($remotes -contains 'origin')) {
        Write-Host "Adding remote origin..."
        git remote add origin $myrepo
    }
}

# Step 2A: Sync posts from Obsidian to Hugo content folder using Robocopy
Write-Host "Syncing posts from Obsidian..."

if (-not (Test-Path $sourcePath)) {
    Write-Error "Source path does not exist: $sourcePath"
    exit 1
}

if (-not (Test-Path $destinationPath)) {
    Write-Error "Destination path does not exist: $destinationPath"
    exit 1
}

# Use Robocopy to mirror the directories
$robocopyOptions = @('/MIR', '/Z', '/W:5', '/R:3')
$robocopyResult = robocopy $sourcePath $destinationPath @robocopyOptions

if ($LASTEXITCODE -ge 8) {
    Write-Error "Robocopy failed with exit code $LASTEXITCODE."
    exit 1
}
# Step 2B: Process Markdown files with Python script to handle image links
Write-Host "Processing image links in Markdown files..."
if (-not (Test-Path "images.py")) {
    Write-Error "Python script images.py not found."
    exit 1
}

# Execute the Python script
try {
    & $pythonCommand images.py
    Write-Host "Image links processed successfully."
} catch {
    Write-Error "Failed to process image links."
    exit 1
}


# Step 3: Update baseURL for deployment
Write-Host "Updating baseURL for deployment..."
Update-BaseURL -newBaseURL "https://markajleejr.github.io/theSecureForge/"

# Step 4: Build the Hugo site
Write-Host "Building the Hugo site..."
$hugoOutput = hugo 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Hugo build failed: $hugoOutput"
    exit 1
}

# Step 5: Revert baseURL to original value
Write-Host "Reverting baseURL to original value..."
Update-BaseURL -newBaseURL $originalBaseURL

# Step 6: Stash changes before pulling updates from GitHub
Write-Host "Stashing local changes before pulling from GitHub..."
git stash save "Stashing changes before pulling latest updates"

# Step 7: Pull the latest changes from GitHub
Write-Host "Pulling latest changes from GitHub..."
$gitPullResult = git pull origin main --rebase
if ($LASTEXITCODE -ne 0) {
    Write-Error "Git pull failed: $gitPullResult"
    exit 1
}

# Step 8: Apply stashed changes back to the working directory
Write-Host "Applying stashed changes..."
git stash pop

# Step 9: Add changes to Git
Write-Host "Staging changes for Git..."
$hasChanges = (git status --porcelain) -ne ""
if (-not $hasChanges) {
    Write-Host "No changes to stage."
} else {
    Write-Host "Staging changes..."
    git add .
}

# Step 10: Commit changes with a dynamic message
$commitMessage = "New Blog Post on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$hasStagedChanges = (git diff --cached --name-only) -ne ""
if (-not $hasStagedChanges) {
    Write-Host "No changes to commit."
} else {
    Write-Host "Committing changes..."
    git commit -m "$commitMessage"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git commit failed."
        exit 1
    }
}

# Step 11: Push all changes to the main branch (or master)
Write-Host "Deploying to GitHub Pages..."
$pushResult = git push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push to main branch."
    exit 1
}

# Step 12: Push the public folder to the gh-pages branch using subtree split and force push
Write-Host "Deploying to GitHub Pages..."

# Check if the temporary branch exists and delete it
$branchExists = git branch --list "gh-pages-deploy"
if ($branchExists) {
    git branch -D gh-pages-deploy
}

# Ensure public folder exists
if (-not (Test-Path "public")) {
    Write-Error "Public folder does not exist. Build the site first."
    exit 1
}

# Perform subtree split to push only the public folder to gh-pages
try {
    git subtree split --prefix public -b gh-pages-deploy
} catch {
    Write-Error "Subtree split failed."
    exit 1
}

# Push to gh-pages branch with force
try {
    git push origin gh-pages-deploy:gh-pages --force
} catch {
    Write-Error "Failed to push to gh-pages branch."
    git branch -D gh-pages-deploy
    exit 1
}

# Delete the temporary branch
git branch -D gh-pages-deploy

Write-Host "All done! Site synced, processed, committed, built, and deployed to GitHub Pages."
