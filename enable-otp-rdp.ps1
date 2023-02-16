# Install required packages
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module Google.Authenticator -Force

# Enable RDP 2nd factor authentication
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "SecurityLayer" -Value 2
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1

# Prompt users to set up TOTP
$ga = New-Object Google.Authenticator.GoogleAuthenticator
$secretKey = $ga.GenerateSecretKey()
$qrCodeUrl = $ga.GetQrCode($env:COMPUTERNAME, $secretKey)
Write-Host "Scan this QR code with your authenticator app to set up TOTP authentication:"
Write-Host $qrCodeUrl
$valid = $false
while (-not $valid) {
    $totpCode = Read-Host "Enter your TOTP code:"
    $valid = $ga.ValidateOneTimePassword($secretKey, $totpCode)
    if (-not $valid) {
        Write-Warning "Invalid TOTP code. Please try again."
    }
}

# Add TOTP authentication to RDP
$totpAuth = @{
    "name" = "TOTP"
    "comment" = "Time-based One-Time Password"
    "dll" = "$((Get-Command 'google-authenticator' | Select -ExpandProperty Source) -replace "\.ps1$",".dll")"
}
$authMethods = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthenticationMethods"
$authMethods.Value += [System.Convert]::ToByte(1) # Add bit for TOTP authentication
$authMethods.Value += [System.Convert]::ToByte(4) # Add bit for smart card authentication
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthenticationMethods" -Value $authMethods.Value
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\UserAuthenticationMethods" -Name "4" -Value $totpAuth -Type "Binary" -Force

Write-Host "TOTP authentication has been set up successfully."
