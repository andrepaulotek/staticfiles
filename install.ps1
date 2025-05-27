$targetDir = "C:\OfficeInstall"
$taskName = "OfficeInstallTask"
$tempUser = "officeAdmin"

Start-Process -FilePath "$targetDir\setup.exe" -ArgumentList "/configure $targetDir\config.xml" -Wait

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-LocalUser -Name $tempUser -ErrorAction SilentlyContinue
    Remove-Item -Path $targetDir -Recurse -Force -ErrorAction SilentlyContinue
} catch {
    # Suppress cleanup errors silently
}