param(
  [string]$Subject,
  [string]$TextBody,
  [string]$HtmlBody = $null,
  [string]$SlackTitle = $null
)
$ErrorActionPreference = "Continue"

function Send-Slack {
  param([string]$title,[string]$text)
  $wh = $env:SLACK_WEBHOOK_URL
  if ([string]::IsNullOrWhiteSpace($wh)) { return $false }
  try {
    $payload = @{ text = ("*{0}*\n{1}" -f $title,$text) }
    Invoke-RestMethod -Method Post -Uri $wh -ContentType "application/json" -Body ($payload | ConvertTo-Json -Compress)
    return $true
  } catch { return $false }
}

function Send-Email {
  param([string]$subject,[string]$text,[string]$html)
  $host  = $env:SMTP_HOST; if ([string]::IsNullOrWhiteSpace($host)) { return $false }
  $port  = if ($env:SMTP_PORT) { [int]$env:SMTP_PORT } else { 587 }
  $user  = $env:SMTP_USER
  $pass  = $env:SMTP_PASS
  $from  = $env:SMTP_FROM
  $to    = $env:SMTP_TO
  $useSsl = ($env:SMTP_SSL -as [string])
  $useSsl = if ($useSsl) { @("1","true","yes") -contains $useSsl.ToLower() } else { $true }

  try {
    $msg = New-Object System.Net.Mail.MailMessage
    $msg.From = $from
    foreach($addr in $to -split ",") { if($addr.Trim()){ $msg.To.Add($addr.Trim()) } }
    $msg.Subject = $subject
    if ($html) { $msg.IsBodyHtml = $true;  $msg.Body = $html }
    else       { $msg.IsBodyHtml = $false; $msg.Body = $text }
    $smtp = New-Object System.Net.Mail.SmtpClient($host,$port)
    $smtp.EnableSsl = $useSsl
    if ($user -and $pass) {
      $secure = ConvertTo-SecureString $pass -AsPlainText -Force
      $cred = New-Object System.Management.Automation.PSCredential($user, $secure)
      $smtp.Credentials = $cred
    }
    $smtp.Send($msg); return $true
  } catch { return $false }
}

$sentSlack = Send-Slack -title ($SlackTitle ?? $Subject) -text $TextBody
$sentMail  = Send-Email  -subject $Subject -text $TextBody -html $HtmlBody
[pscustomobject]@{ slack=$sentSlack; email=$sentMail }
