<powershell>
<#
.SYNOPSIS
    Installs and configures Nginx as a Windows service using port 81.
.DESCRIPTION
    Downloads Nginx, extracts it, sets up a Windows service, and opens the firewall for HTTP (port 81).
.NOTES
    Run this script as Administrator.
#>


#Define varables
$LogFile = "C:\UserData_in_s3.log"

# Function to log messages
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append
}

# Define variables
$LogFile = "C:\Nginx_Install.log"
$NginxVersion = "1.25.3"
$InstallDir = "C:\nginx"
$DownloadUrl = "https://nginx.org/download/nginx-$NginxVersion.zip"
$Port = 81  # Using 81 to avoid common conflicts

# Ensure admin rights
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Restarting as Administrator..."
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

# Create installation directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Host "Created directory: $InstallDir"
}

# Download Nginx
$ZipPath = "$env:TEMP\nginx-$NginxVersion.zip"
Write-Host "Downloading Nginx..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing

# Extract Nginx
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force

# Move files from subfolder
$ExtractedFolder = Get-ChildItem -Path $InstallDir -Directory -Filter "nginx-*" | Select-Object -First 1
if ($ExtractedFolder) {
    Move-Item -Path "$($ExtractedFolder.FullName)\*" -Destination $InstallDir -Force
    Remove-Item -Path $ExtractedFolder.FullName -Force
}

# Configure Nginx
$NginxConfPath = "$InstallDir\conf\nginx.conf"
(Get-Content $NginxConfPath) -replace 'listen\s+80;', "listen $Port;" | Set-Content $NginxConfPath

# Set permissions
icacls $InstallDir /grant "Everyone:(OI)(CI)F" /T

# Install service (proper method)
$ServiceName = "nginx"
if (Get-Service $ServiceName -ErrorAction SilentlyContinue) {
    Stop-Service $ServiceName -Force
    sc.exe delete $ServiceName
}

Start-Process -FilePath "$InstallDir\nginx.exe" -Wait
Start-Sleep -Seconds 2
Stop-Process -Name "nginx" -Force -ErrorAction SilentlyContinue

# Create service manually for better reliability
sc.exe create $ServiceName binPath= "`"$InstallDir\nginx.exe`" -p `"$InstallDir`"" start= auto DisplayName= "Nginx Web Server"
Start-Service $ServiceName

# Configure firewall
if (-not (Get-NetFirewallRule -Name "Nginx_HTTP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "Nginx_HTTP" -DisplayName "Nginx HTTP (TCP $Port)" `
        -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Enabled True | Out-Null
}

# Verify
Start-Sleep -Seconds 3
try {
    $nginxProcess = Get-Process -Name "nginx" -ErrorAction Stop
    Write-Host "Nginx running (PID: $($nginxProcess.Id)). Access: http://localhost:$Port"
    
    # Test connection
    $response = Invoke-WebRequest "http://localhost:$Port" -UseBasicParsing -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "Nginx is serving requests successfully!"
    } else {
        Write-Warning "Nginx responded with status $($response.StatusCode)"
    }
} catch {
    Write-Error "Nginx failed to start. Check $InstallDir\logs\error.log"
    Get-Content "$InstallDir\logs\error.log" -Tail 20
}

# Cleanup
Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
</powershell>

# #!/bin/bash -xe
# exec > /tmp/script_output.log 2>&1 
# sleep 10
# sudo apt update
# sudo apt install wget unzip -y
# sudo apt install nginx -y
# sudo ufw allow 'Nginx HTTP'
# sudo ufw status
# sudo systemctl start nginx
# sudo systemctl enable nginx
# sudo systemctl status nginx
# cd /tmp    #This next command will fall because, you might not have the permissiont o write to the file system, hence you are using the /tmp directory where you dont need such permission
# wget https://www.tooplate.com/zip-templates/2137_barista_cafe.zip
# # if [ -f "2137_barista_cafe.zip" ]; then
# sudo mkdir -p /var/www/html
# sudo unzip 2137_barista_cafe.zip -d /var/www/html
# sudo cp -r /var/www/html/2137_barista_cafe/* /var/www/html
# sudo nginx -s reload
# sudo systemctl restart nginx
# # else
#     # echo "Something went wrong while downloading the file"
# # fi