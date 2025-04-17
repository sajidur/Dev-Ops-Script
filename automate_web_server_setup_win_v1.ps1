# Define Variables
$UserName = "Teacher"
$Password = "Password123#"
$SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
$apacheZip = "C:\Apache.zip"
$apacheDir = "C:\Apache24"
$httpdConfPath = "$apacheDir\conf\httpd.conf"

Write-Host "Starting Apache installation on Windows Server 2022 Datacenter..."

# 1. Create a Local User if not exists
if (-Not (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating user '$UserName'..."
    New-LocalUser -Name $UserName -Password $SecurePassword -FullName "Teacher" -Description "Teacher User Account"
    Add-LocalGroupMember -Group "Administrators" -Member $UserName
    Write-Host "User '$UserName' created successfully."
} else {
    Write-Host "User '$UserName' already exists. Skipping user creation."
}

# 2. Extract Apache if not already extracted
if (-Not (Test-Path $apacheDir)) {
    if (Test-Path $apacheZip) {
        Write-Host "Extracting Apache..."
        Expand-Archive -Path $apacheZip -DestinationPath C:\ -Force
        Write-Host "Extraction complete."
    } else {
        Write-Host "Apache ZIP file not found at $apacheZip! Ensure it is available."
        Exit
    }
} else {
    Write-Host "Apache is already extracted. Skipping extraction."
}

# 3. Configure Apache to Listen on Port 8080
if (Test-Path $httpdConfPath) {
    # Backup Original Configuration
    Copy-Item -Path $httpdConfPath -Destination "$httpdConfPath.bak" -Force
    Write-Host "Backup of httpd.conf created."

    # Update Listen Port to 8080
    (Get-Content $httpdConfPath) -replace "Listen 80", "Listen 8080" | Set-Content $httpdConfPath
    (Get-Content $httpdConfPath) -replace "ServerName localhost:80", "ServerName localhost:8080" | Set-Content $httpdConfPath
    Write-Host "Apache configuration updated to use port 8080."
} else {
    Write-Host "Apache configuration file not found! Exiting."
    Exit
}

# 4. Install Apache as a Windows Service
$httpdPath = "$apacheDir\bin\httpd.exe"
if (Test-Path $httpdPath) {
    Write-Host "Installing Apache as a Windows Service..."
    Start-Process -FilePath $httpdPath -ArgumentList "-k install" -Wait -NoNewWindow
    Write-Host "Apache service installed."

    # Start Apache Service
    Start-Service -Name "Apache2.4"
    Write-Host "Apache started successfully on port 8080."
} else {
    Write-Host "Apache executable not found! Check the extraction path."
    Exit
}

# 5. Open Firewall for Apache (Port 8080)
Write-Host "Configuring Windows Firewall for Apache..."
New-NetFirewallRule -DisplayName "Allow Apache on 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
Write-Host "Port 8080 is now open in the firewall."

# 6. Remove Apache ZIP File After Extraction
if (Test-Path $apacheZip) {
    Remove-Item -Path $apacheZip -Force
    Write-Host "Removed Apache ZIP file."
}

# 7. Enable Remote Desktop (RDP)
Write-Host "Enabling Remote Desktop (RDP)..."
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1
Restart-Service -Name TermService -Force
Write-Host "Remote Desktop has been enabled successfully!"

Write-Host "Setup Complete! Apache is running on port 8080."
