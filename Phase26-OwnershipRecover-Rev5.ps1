# Phase26-OwnershipRecover-Rev5.ps1
# Safely recover truvern.com domain and assign it to nelson-addaes-projects

[CmdletBinding()]
param(
  [string]$Domain = 'truvern.com',
  [string]$TargetScope = 'nelson-addaes-projects',
  [string]$ProjectName = 'truvern'
)

$ErrorActionPreference = 'Stop'
function Note($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }

function RunVercel($argsLine) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/c vercel $argsLine"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  [void]$proc.Start()
  $output = $proc.StandardOutput.ReadToEnd()
  $error = $proc.StandardError.ReadToEnd()
  $proc.WaitForExit()

  [PSCustomObject]@{
    Code = $proc.ExitCode
    Out  = $output
    Err  = $error
  }
}

Note "=== Phase26: Domain Ownership Recover for $Domain ===" "Cyan"

$candidateScopes = @(
  'nelson-addaes-projects',
  'nelson-ai-projects',
  'nelson-ai-projectss',
  'personal'
)

$ownerScope = $null
$inaccessible = @()

foreach ($scope in $candidateScopes) {
  Note "-> Trying scope: $scope" "DarkGray"
  $switch = RunVercel "switch $scope"
  if ($switch.Code -ne 0 -or $switch.Err -match 'permission|not authorized') {
    Note "  ! Cannot switch to $scope" "Yellow"
    $inaccessible += $scope
    continue
  }

  $list = RunVercel "domains ls"
  if ($list.Code -ne 0) {
    Note "  ! domains ls failed in $scope" "Yellow"
    continue
  }

  if (($list.Out + $list.Err) -match [regex]::Escape($Domain)) {
    $ownerScope = $scope
    Note "  Found $Domain in scope: $scope" "Green"
    break
  }
  else {
    Note "  Not found in $scope" "DarkGray"
  }
}

if (-not $ownerScope) {
  Note "No accessible scope contained the domain." "Yellow"
  if ($inaccessible.Count -gt 0) {
    Note "Scopes not accessible: $($inaccessible -join ', ')" "Yellow"
  }

  $who = RunVercel "whoami"
  Note ""
  Note "Copy this message to Vercel Support:" "White"
  Write-Host @"
Subject: Please release/transfer domain truvern.com to team 'nelson-addaes-projects'

Hello Vercel Support,
I am $($who.Out + $who.Err).
Please release or transfer the domain 'truvern.com' from an inaccessible team
(likely 'Nelson AI Projects') to my active team 'nelson-addaes-projects'.
I can verify DNS ownership.

Thanks!
"@ -ForegroundColor Gray
  exit 0
}

Note "Releasing $Domain from $ownerScope ..." "Cyan"
$rm = RunVercel "domains rm $Domain --yes"
if ($rm.Code -ne 0 -and ($rm.Out + $rm.Err) -notmatch 'not found') {
  Note "Remove failed: $($rm.Out + $rm.Err)" "Red"
  exit 1
}
Note "Released successfully." "Green"

Note "Switching to target scope: $TargetScope" "Cyan"
$sw2 = RunVercel "switch $TargetScope"
if ($sw2.Code -ne 0) {
  Note "Failed to switch: $($sw2.Out + $sw2.Err)" "Red"
  exit 1
}

Note "Adding domain to $TargetScope ..." "Cyan"
$add = RunVercel "domains add $Domain"
if ($add.Code -ne 0 -and ($add.Out + $add.Err) -notmatch 'already exists') {
  Note "domains add failed: $($add.Out + $add.Err)" "Red"
  exit 1
}
Note "Domain present under $TargetScope" "Green"

Note "Locating production URL for $ProjectName ..." "DarkGray"
$pls = RunVercel "project ls"
$prodHost = $null

foreach ($line in ($pls.Out + $pls.Err -split "`r?`n")) {
  if ($line -match ("^\s*$ProjectName\s+https?://([a-z0-9\.-]+)")) {
    $prodHost = $matches[1]
    break
  }
}

if (-not $prodHost) {
  $prodHost = "$ProjectName.vercel.app"
}

Note "Using deployment host: $prodHost" "DarkGray"
Note "Creating alias: $prodHost -> $Domain" "Cyan"
$alias = RunVercel "alias set $prodHost $Domain"
if ($alias.Code -ne 0) {
  Note "alias set failed: $($alias.Out + $alias.Err)" "Red"
  exit 1
}

Note "==================================================" "DarkGray"
Note "SUCCESS: $Domain now points to $prodHost under $TargetScope." "Green"
Note "Verify with: vercel alias ls | findstr $Domain" "DarkGray"

Write-Host ""
Write-Host "Press Enter to close..." -ForegroundColor Yellow
[void][System.Console]::ReadLine()
