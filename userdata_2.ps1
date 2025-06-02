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


# Parameters
$NginxVersion = "1.25.3"
$InstallDir = "C:\nginx"
$DownloadUrl = "https://nginx.org/download/nginx-$NginxVersion.zip"
$Port = 81  # Changed to port 81

# Ensure script is running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator. Restarting with elevated privileges..."
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
Write-Host "Downloading Nginx $NginxVersion..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath

# Extract Nginx
Write-Host "Extracting Nginx to $InstallDir..."
Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force

# Move files from subfolder to root (Nginx extracts into a versioned subdirectory)
$ExtractedFolder = Get-ChildItem -Path $InstallDir -Directory | Where-Object { $_.Name -like "nginx*" } | Select-Object -First 1
if ($ExtractedFolder) {
    Get-ChildItem -Path $ExtractedFolder.FullName | Move-Item -Destination $InstallDir -Force
    Remove-Item -Path $ExtractedFolder.FullName -Force
}

# Modify Nginx configuration to use port 81
$NginxConfPath = "$InstallDir\conf\nginx.conf"
(Get-Content $NginxConfPath) -replace 'listen\s+80;', "listen       $Port;" | Set-Content $NginxConfPath
Write-Host "Configured Nginx to use port $Port"

# Install Nginx as a Windows service
$NginxExePath = "$InstallDir\nginx.exe"
if (Test-Path $NginxExePath) {
    Write-Host "Installing Nginx service..."
    
    # Temporarily start Nginx to register the service
    Start-Process -FilePath $NginxExePath -NoNewWindow -Wait
    
    # Stop Nginx (it auto-starts after install)
    Start-Sleep -Seconds 2
    Stop-Process -Name "nginx" -Force -ErrorAction SilentlyContinue
    
    # Configure service to auto-start
    Set-Service -Name "nginx" -StartupType Automatic -ErrorAction SilentlyContinue
    
    # Start Nginx service
    Start-Service -Name "nginx" -ErrorAction SilentlyContinue
    Write-Host "Nginx service started."
} else {
    Write-Error "Nginx executable not found at $NginxExePath"
    exit 1
}

# Add firewall rule for HTTP (port 81)
Write-Host "Configuring firewall for HTTP (port $Port)..."
if (-not (Get-NetFirewallRule -Name "Nginx_HTTP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "Nginx_HTTP" -DisplayName "Nginx HTTP (TCP $Port)" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Enabled True | Out-Null
}

# Verify Nginx is running
try {
    $nginxProcess = Get-Process -Name "nginx" -ErrorAction Stop
    Write-Host "Nginx is running (PID: $($nginxProcess.Id)). Open http://localhost:$Port in your browser."
    Write-Log "nginx is running"

    # Verify port is listening
    $listening = netstat -ano | findstr ":$Port"
    if (-not $listening) {
        Write-Warning "Nginx is not listening on port $Port. Check configuration."
        Write-Log "successful installation"
    }
} catch {
    Write-Error "Nginx failed to start. Check logs in $InstallDir\logs\error.log"
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