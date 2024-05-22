function Invoke-PortScan {
    param (
        [string]$TargetHost,
        [int[]]$Ports = @(80, 443)  # Default ports to scan if none are provided
    )

    foreach ($Port in $Ports) {
        $result = Test-NetConnection -ComputerName $TargetHost -Port $Port
        if ($result.TcpTestSucceeded) {
            Write-Host "Port $Port on $TargetHost is open."
        } else {
            Write-Host "Port $Port on $TargetHost is closed."
        }
    }
}
