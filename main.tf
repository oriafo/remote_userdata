terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
    access_key = "<access_key>"
    secret_key = "<secret_key>"
    region = "us-east-1"
}


resource "aws_instance" "win_server_arm" {
  ami           = "ami-0fa71268a899c2733"
  associate_public_ip_address = true  
  instance_type = "t3.medium" 
  key_name              = "<key>"
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  user_data = <<EOF
<powershell>
# PowerShell UserData script to download and execute a script from an S3 bucket

# Define variables
$BucketName = "client-portal-userdata-2024"  
$ScriptKey = "userdata_2.ps1"
$LocalScriptPath = "C:\downloaded_script.ps1"  # Changed to direct file path
$Region = "us-east-1"
$LogFile = "C:\UserData.log"

# Function to log messages
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append
}

# Function to install AWS CLI if not present
function Install-AWSCLI {
    try {
        if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
            Write-Log "AWS CLI not found. Installing AWS CLI..."
            $installerUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
            $installerPath = "$env:TEMP\AWSCLIV2.msi"
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $installerPath /quiet /norestart" -Wait
            Remove-Item $installerPath -Force
            $env:Path += ";C:\Program Files\Amazon\AWSCLIV2"
            Write-Log "AWS CLI installed successfully."
        } else {
            Write-Log "AWS CLI already installed."
        }
    }
    catch {
        Write-Log "Error installing AWS CLI: $_"
        exit 1
    }
}

# Function to download script from S3
function Download-ScriptFromS3 {
    param (
        [string]$BucketName,
        [string]$ScriptKey,
        [string]$LocalScriptPath,
        [string]$Region
    )
    try {
        Write-Log "Downloading script from S3 bucket: $BucketName/$ScriptKey"
        aws s3 cp "s3://$BucketName/$ScriptKey" $LocalScriptPath --region $Region
        if (-not (Test-Path $LocalScriptPath)) {
            Write-Log "Failed to download the script from S3."
            exit 1
        }
        Write-Log "Script successfully downloaded to $LocalScriptPath"
    }
    catch {
        Write-Log "Error downloading script: $_"
        exit 1
    }
}

# Function to execute the downloaded script
function Execute-Script {
    param (
        [string]$ScriptPath
    )
    try {
        if (-not ($ScriptPath.EndsWith(".ps1"))) {
            Write-Log "The downloaded file is not a PowerShell script (.ps1)."
            exit 1
        }

        Write-Log "Executing script: $ScriptPath"
        PowerShell -ExecutionPolicy Bypass -File $ScriptPath
        Write-Log "Script executed successfully."
    }
    catch {
        Write-Log "Error executing script: $_"
        exit 1
    }
}

# Main execution
try {
    Write-Log "Starting UserData script execution."

    # Install AWS CLI if needed
    Install-AWSCLI

    # Download the script
    Download-ScriptFromS3 -BucketName $BucketName -ScriptKey $ScriptKey -LocalScriptPath $LocalScriptPath -Region $Region

    # Execute the script
    Execute-Script -ScriptPath $LocalScriptPath
}
catch {
    Write-Log "Fatal error in UserData script: $_"
    exit 1
}
finally {
    # Clean up
    if (Test-Path $LocalScriptPath) {
        Remove-Item $LocalScriptPath -Force
        Write-Log "Cleaned up downloaded script: $LocalScriptPath"
    }
    Write-Log "UserData script execution completed."
}
</powershell>
EOF            
  depends_on = [aws_s3_bucket.client_portal_userdata_script]
  tags = {
    Name = "Windows-2022-ARM"
  }
}

