# This script is downloaded and executed by the scheduled task.
# It assumes it's running from C:\ZebraInstall

# --- 1. Configuration ---
$LogFile = "C:\ZebraInstall\InstallLog.txt"
function Write-Log { param($Message) "$([datetime]::now) - $Message" | Out-File -FilePath $LogFile -Append }

# Clear previous log file
if (Test-Path $LogFile) { Remove-Item $LogFile -Force }

Write-Log "--- Worker script started. ---"

try {
    # --- 2. Setup Paths ---
    $BaseDir = "C:\ZebraInstall"
    $LocalDriversPath = "$BaseDir\zebradasriscas"
    $PrinterConfigFile = "$BaseDir\printers.json"
    
    Write-Log "Base directory is: $BaseDir"

    # --- 3. Extraction ---
    Write-Log "Creating driver directory: $LocalDriversPath"
    New-Item -Path $LocalDriversPath -ItemType Directory -Force | Out-Null

    Write-Log "Extracting zbrn.inf.zip..."
    Expand-Archive -Path "$BaseDir\zbrn.inf.zip" -DestinationPath $LocalDriversPath -Force
    
    Write-Log "Extracting zdesigner.inf.zip..."
    Expand-Archive -Path "$BaseDir\zdesigner.inf.zip" -DestinationPath $LocalDriversPath -Force
    Write-Log "Extraction complete."

    # --- 4. Perform Driver Installation ---
    Write-Log "Starting driver installation..."

    $driverPaths = @(
        "$LocalDriversPath\zbrn.inf_amd64_0544165b7b62acd8\ZBRN.inf",
        "$LocalDriversPath\zdesigner.inf_amd64_29e0f86ca9e762fb\ZDesigner.inf"
    )

    foreach ($driverInf in $driverPaths) {
        if (Test-Path $driverInf) {
            Write-Log "Installing driver: $driverInf"
            pnputil /add-driver "`"$driverInf`"" /install | Out-File -FilePath $LogFile -Append
        } else {
            Write-Log "ERROR: Driver INF file not found: $driverInf"
        }
    }
    Write-Log "Driver installation phase complete."

    # --- 5. Install Printers from Config File ---
    Write-Log "Reading printer configuration from $PrinterConfigFile..."
    if (-not (Test-Path $PrinterConfigFile)) {
        throw "Printer configuration file not found at $PrinterConfigFile"
    }
    
    # Read the JSON file and convert it into a PowerShell object
    $printersToInstall = Get-Content -Path $PrinterConfigFile | ConvertFrom-Json

    $zebraDriverName = "ZDesigner ZD411-203dpi ZPL"
    
    Write-Log "Starting printer configuration..."
    # Loop through the properties of the object
    foreach ($printerEntry in $printersToInstall.PSObject.Properties) {
        $printerName = $printerEntry.Name
        $printerIP = $printerEntry.Value
        $portName = "IP_$($printerIP)"

        try {
            if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
                Write-Log "Adding port $portName..."
                Add-PrinterPort -Name $portName -PrinterHostAddress $printerIP -ErrorAction Stop
            }
            if (-not (Get-Printer -Name $printerName -ErrorAction SilentlyContinue)) {
                 Write-Log "Adding printer $printerName..."
                 Add-Printer -Name $printerName -DriverName $zebraDriverName -PortName $portName -ErrorAction Stop
            }
        }
        catch {
            Write-Log "ERROR: Failed to configure printer '$printerName'. Error: $($_.Exception.Message)"
        }
    }
    Write-Log "Printer configuration phase complete."
}
catch {
    Write-Log "CRITICAL ERROR: $($_.Exception.Message)"
}
finally {
    Write-Log "--- Worker script finished. ---"
}
