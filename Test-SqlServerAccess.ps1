function Test-SqlServerAccess {
    <#
    .SYNOPSIS
        Scans SQL Server related ports and tests a login against open TDS ports.
    .PARAMETER AuthMode
        Sql     = SQL Server authentication using -Credential (required).
        Windows = Integrated auth. Without -Credential uses the current user.
                  With -Credential runs the login test in a job under that account.
    .EXAMPLE
        Test-SqlServerAccess -ComputerName SQLDEV01 -Credential (Get-Credential) | Format-Table
    .EXAMPLE
        Test-SqlServerAccess -ComputerName SQLDEV01 -AuthMode Windows -Credential (Get-Credential 'domain\svc_etl')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName,

        [ValidateSet('Sql', 'Windows')]
        [string]$AuthMode = 'Sql',

        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [int[]]$Ports = @(135, 1433, 1434, 2383, 4022, 5022),

        [int[]]$ExcludeFromLogin = @(135, 1434, 2383, 4022, 5022),

        [ValidateRange(100, 30000)]
        [int]$TimeoutMs = 1500,

        [ValidateRange(1, 60)]
        [int]$LoginTimeoutSec = 5,

        [string]$Database = 'master',

        [switch]$Encrypt,

        [switch]$TrustServerCertificate
    )

    begin {
        $ErrorActionPreference = 'Stop'
        $hasCred = $Credential -ne [System.Management.Automation.PSCredential]::Empty

        if ($AuthMode -eq 'Sql') {
            if (-not $hasCred) { throw 'AuthMode Sql requires -Credential.' }
            if ($Credential.UserName -match '[\\@]') {
                throw "'$($Credential.UserName)' looks like a Windows account. Use -AuthMode Windows."
            }
        }

        $portNames = @{
            135  = 'RPC Endpoint Mapper (MSDTC / XA)'
            1433 = 'SQL Server default instance'
            1434 = 'DAC (TCP) / SQL Browser (UDP)'
            2383 = 'SSAS default instance'
            4022 = 'Service Broker'
            5022 = 'AG / Mirroring endpoint'
        }

        function Test-TcpPort {
            param([string]$HostName, [int]$Port, [int]$Timeout)
            $client = New-Object System.Net.Sockets.TcpClient
            try {
                $async = $client.BeginConnect($HostName, $Port, $null, $null)
                if (-not $async.AsyncWaitHandle.WaitOne($Timeout, $false)) { return 'Filtered/Timeout' }
                $client.EndConnect($async)
                return 'Open'
            }
            catch {
                $inner = $_.Exception
                while ($inner.InnerException) { $inner = $inner.InnerException }
                if ($inner -is [System.Net.Sockets.SocketException]) { return 'Closed' }
                return ('Error: ' + $inner.Message)
            }
            finally { $client.Close() }
        }

        function Get-SqlBrowserInstances {
            param([string]$HostName, [int]$Timeout)
            $udp = New-Object System.Net.Sockets.UdpClient
            try {
                $udp.Client.ReceiveTimeout = $Timeout
                $udp.Connect($HostName, 1434)
                $null = $udp.Send([byte[]]@(0x02), 1)
                $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                $bytes = $udp.Receive([ref]$remote)
                if ($bytes.Length -lt 4 -or $bytes[0] -ne 0x05) { return }
                $text = [System.Text.Encoding]::ASCII.GetString($bytes, 3, $bytes.Length - 3)
                foreach ($chunk in ($text -split ';;' | Where-Object { $_ })) {
                    $parts = $chunk -split ';'
                    $props = @{}
                    for ($i = 0; $i -lt $parts.Count - 1; $i += 2) { $props[$parts[$i]] = $parts[$i + 1] }
                    [pscustomobject]@{
                        InstanceName = $props['InstanceName']
                        Version      = $props['Version']
                        TcpPort      = $props['tcp']
                    }
                }
            }
            catch { return }
            finally { $udp.Close() }
        }

        $loginBlock = {
            param([string]$ConnStr, [string]$User, [System.Security.SecureString]$Pw)
            $conn = New-Object System.Data.SqlClient.SqlConnection $ConnStr
            try {
                if ($User) { $conn.Credential = New-Object System.Data.SqlClient.SqlCredential($User, $Pw) }
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = "SELECT @@SERVERNAME, CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)), SUSER_SNAME(), IS_SRVROLEMEMBER('sysadmin')"
                $reader = $cmd.ExecuteReader()
                $null = $reader.Read()
                $out = [pscustomobject]@{
                    ConnStr    = $ConnStr
                    Success    = $true
                    LoginAs    = $reader.GetValue(2)
                    ServerName = $reader.GetValue(0)
                    Version    = $reader.GetValue(1)
                    IsSysadmin = ($reader.GetValue(3) -eq 1)
                    Error      = $null
                }
                $reader.Close()
                $out
            }
            catch {
                $ex = $_.Exception
                while ($ex.InnerException -and -not ($ex -is [System.Data.SqlClient.SqlException])) { $ex = $ex.InnerException }
                $msg = if ($ex -is [System.Data.SqlClient.SqlException]) { 'SQL ' + $ex.Number + ': ' + $ex.Message } else { $ex.Message }
                [pscustomobject]@{
                    ConnStr    = $ConnStr
                    Success    = $false
                    LoginAs    = $null
                    ServerName = $null
                    Version    = $null
                    IsSysadmin = $null
                    Error      = $msg
                }
            }
            finally { $conn.Dispose() }
        }
    }

    process {
        foreach ($computer in $ComputerName) {
            Write-Verbose "Querying SQL Browser on $computer"
            $instances = @(Get-SqlBrowserInstances -HostName $computer -Timeout $TimeoutMs)
            $instancePorts = @{}
            foreach ($inst in $instances) {
                if ($inst.TcpPort) { $instancePorts[[int]$inst.TcpPort] = 'Instance ' + $inst.InstanceName + ' (Browser)' }
            }
            $scanPorts = @($Ports + @($instancePorts.Keys) | Sort-Object -Unique)

            $portResults = foreach ($p in $scanPorts) {
                $svc = if ($instancePorts.ContainsKey($p)) { $instancePorts[$p] }
                       elseif ($portNames.ContainsKey($p)) { $portNames[$p] }
                       else { 'User-specified' }
                [pscustomobject]@{
                    Port       = $p
                    Service    = $svc
                    PortStatus = Test-TcpPort -HostName $computer -Port $p -Timeout $TimeoutMs
                }
            }

            $loginTargets = @{}
            foreach ($r in ($portResults | Where-Object { $_.PortStatus -eq 'Open' -and $ExcludeFromLogin -notcontains $_.Port })) {
                $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
                $b['Data Source']            = 'tcp:' + $computer + ',' + $r.Port
                $b['Initial Catalog']        = $Database
                $b['Connect Timeout']        = $LoginTimeoutSec
                $b['Pooling']                = $false
                $b['Encrypt']                = [bool]$Encrypt
                $b['TrustServerCertificate'] = [bool]$TrustServerCertificate
                $b['Application Name']       = 'Test-SqlServerAccess'
                if ($AuthMode -eq 'Windows') { $b['Integrated Security'] = $true }
                $loginTargets[$b.ConnectionString] = $r.Port
            }

            $loginResults = @{}
            if ($loginTargets.Count -gt 0) {
                if ($AuthMode -eq 'Sql') {
                    $pw = $Credential.Password.Copy()
                    $pw.MakeReadOnly()
                    foreach ($cs in $loginTargets.Keys) {
                        $res = & $loginBlock $cs $Credential.UserName $pw
                        $loginResults[$loginTargets[$cs]] = $res
                    }
                }
                elseif (-not $hasCred) {
                    foreach ($cs in $loginTargets.Keys) {
                        $res = & $loginBlock $cs $null $null
                        $loginResults[$loginTargets[$cs]] = $res
                    }
                }
                else {
                    Write-Verbose "Running Windows auth test as $($Credential.UserName) in a background job"
                    $jobBlock = {
                        param([string]$Code, [string[]]$Conns)
                        $sb = [scriptblock]::Create($Code)
                        foreach ($c in $Conns) { & $sb $c $null $null }
                    }
                    $job = Start-Job -ScriptBlock $jobBlock -Credential $Credential `
                        -ArgumentList $loginBlock.ToString(), ([string[]]@($loginTargets.Keys))
                    $null = Wait-Job -Job $job -Timeout (($LoginTimeoutSec + 5) * $loginTargets.Count + 30)
                    if ($job.State -ne 'Completed') {
                        $jobErr = 'Job state ' + $job.State + '. ' + (($job.ChildJobs | ForEach-Object { $_.JobStateInfo.Reason.Message }) -join ' ')
                        Stop-Job -Job $job -ErrorAction SilentlyContinue
                        foreach ($cs in $loginTargets.Keys) {
                            $loginResults[$loginTargets[$cs]] = [pscustomobject]@{ Success = $false; Error = $jobErr }
                        }
                    }
                    else {
                        foreach ($res in (Receive-Job -Job $job)) { $loginResults[$loginTargets[$res.ConnStr]] = $res }
                    }
                    Remove-Job -Job $job -Force
                }
            }

            foreach ($r in $portResults) {
                $lr = $loginResults[$r.Port]
                [pscustomobject]@{
                    ComputerName = $computer
                    Port         = $r.Port
                    Service      = $r.Service
                    PortStatus   = $r.PortStatus
                    LoginTested  = [bool]$lr
                    LoginSuccess = if ($lr) { $lr.Success } else { $null }
                    LoginAs      = if ($lr) { $lr.LoginAs } else { $null }
                    ServerName   = if ($lr) { $lr.ServerName } else { $null }
                    Version      = if ($lr) { $lr.Version } else { $null }
                    IsSysadmin   = if ($lr) { $lr.IsSysadmin } else { $null }
                    Error        = if ($lr) { $lr.Error } else { $null }
                }
            }
        }
    }
}
