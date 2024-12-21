# PowerShell Script for Windows

# Set variables for paths and repository
$sourcePath = "C:\Users\marka\Documents\Mark's Vault\posts"
$destinationPath = "C:\Users\marka\Documents\theSecureForge\content\posts"
#$hugoConfigPath = "C:\Users\marka\Documents\theSecureForge\Hugo.toml" --disabled Hugo auto update
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

<# # Function to update baseURL in Hugo.toml --disabled Hugo auto update
function Update-BaseURL {
    param (
        [string]$newBaseURL
    )
    if (-not (Test-Path $hugoConfigPath)) {
        Write-Error "Hugo configuration file not found: $hugoConfigPath"
        exit 1
    }

    try {
        $configContent = Get-Content $hugoConfigPath -Raw -Encoding UTF8
		$updatedContent = $configContent -replace '(?m)^\s*baseURL\s*=\s*["\''].*?["\'']', "baseURL = `"$newBaseURL`""
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($hugoConfigPath, $updatedContent, $utf8NoBom)

        Write-Host "baseURL successfully updated to: $newBaseURL"
    } catch {
        Write-Error "Failed to update baseURL in Hugo configuration file."
        exit 1
    }
}

# Extract the current baseURL from Hugo.toml
if (-not (Test-Path $hugoConfigPath)) {
    Write-Error "Hugo configuration file not found: $hugoConfigPath"
    exit 1
}

try {
    $configContent = Get-Content $hugoConfigPath -Raw -Encoding UTF8
    if ($configContent -match '(?m)^\s*baseURL\s*=\s*["\''].*?["\'']') {
		$originalBaseURL = $matches[1]
        Write-Host "Original baseURL extracted: $originalBaseURL"
    } else {
        Write-Error "Could not extract baseURL from Hugo config file. Ensure it is properly defined."
        $originalBaseURL = "/"
    }
} catch {
    Write-Error "Failed to read Hugo configuration file."
    exit 1
} #>

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

try {
    python images.py
    Write-Host "Image links processed successfully."
} catch {
    Write-Error "Failed to process image links."
    exit 1
}

<# # Step 3: Update baseURL for deployment --disabled Hugo auto update
Write-Host "Updating baseURL for deployment..."
Update-BaseURL -newBaseURL "https://markajleejr.github.io/theSecureForge/" #>

# Step 4: Build the Hugo site
Write-Host "Building the Hugo site..."
$hugoOutput = hugo 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Hugo build failed: $hugoOutput"
    exit 1
}

<# # Step 5: Revert baseURL to original value --disabled Hugo auto update
Write-Host "Reverting baseURL to original value..."
Update-BaseURL -newBaseURL $originalBaseURL #>

<# # Step 6: Stash Hugo.toml changes before pulling updates from GitHub --disabled Hugo auto update
Write-Host "Stashing local changes before pulling from GitHub..."
git stash push -m "Temporary stash for Hugo.toml" Hugo.toml #>

# Step 7: Pull the latest changes from GitHub
Write-Host "Pulling latest changes from GitHub..."
$gitPullResult = git pull origin main --rebase
if ($LASTEXITCODE -ne 0) {
    if ($gitPullResult -like "*needs merge*") {
        Write-Error "Merge conflict detected in Hugo.toml. Please resolve the conflict manually."
        git status
        exit 1
    } else {
        Write-Error "Git pull failed: $gitPullResult"
        exit 1
    }
}

<# # Step 8: Apply stashed changes back to Hugo.toml --disabled Hugo auto update
Write-Host "Applying stashed changes..."
$gitStashPopResult = git stash pop
if ($LASTEXITCODE -ne 0) {
    if ($gitStashPopResult -like "*conflict*") {
        Write-Error "Merge conflict detected while applying stashed changes. Please resolve the conflict manually."
        git status
        exit 1
    } else {
        Write-Error "Failed to apply stashed changes: $gitStashPopResult"
        exit 1
    }
} #>

# Step 9: Add changes to Git
Write-Host "Staging changes for Git..."
if ((git status --porcelain) -ne "") {
    Write-Host "Staging changes..."
    git add .
    $commitMessage = "New Blog Post on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    git commit -m "$commitMessage"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git commit failed."
        exit 1
    }
} else {
    Write-Host "No changes to stage or commit."
}

# Step 10: Deploy to GitHub Pages
Write-Host "Deploying to GitHub Pages..."
if (-not (Test-Path "public")) {
    Write-Error "Public folder does not exist. Build the site first."
    exit 1
}

try {
    git subtree split --prefix public -b gh-pages-deploy
    git push origin gh-pages-deploy:gh-pages --force
    git branch -D gh-pages-deploy
    Write-Host "Site deployed to GitHub Pages successfully."
} catch {
    Write-Error "Deployment to GitHub Pages failed."
    exit 1
}
