# Stop on first error
$ErrorActionPreference = "Stop"

# Remove node_modules folder if it exists
if (Test-Path "node_modules") {
    Remove-Item -Recurse -Force "node_modules"
}

# Remove package-lock.json if it exists
if (Test-Path "package-lock.json") {
    Remove-Item -Force "package-lock.json"
}

# Clear the npm cache
npm cache clean --force

# Install dependencies
npm install
