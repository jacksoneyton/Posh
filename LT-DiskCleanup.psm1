##Functions to Get Folder Sizes on C: for specific cleanable folders
Function Get-FolderSize
    {
    <# 
    .SYNOPSIS 
    Get-FolderSize will recursively search all files and folders at a given path to show the total size 
    
    .DESCRIPTION 
    Get-FolderSize accepts a file path through the Path parameter and then recursively searches the directory in order to calculate the overall file size.  
    The size is displayed in GB, MB, or KB depending on the Unit selected, defaults to GB.  Will accept Multiple paths. 
    
    .EXAMPLE  
    Get-FolderSize -path C:\users\Someuser\Desktop 
    
    Returns the size of the desktop folder in Gigabytes 
    
    .EXAMPLE  
    Get-FolderSize -path \\Server\Share\Folder, c:\custom\folder -unit MB 
    
    Returns the size of the folders, \\Server\Share\Folder and C:\Custom\Folder, in Megabytes 
    
    #> 
    [CmdletBinding()] 
    Param 
        ( 
            # Enter the path to the target folder 
            [Parameter( 
            ValueFromPipeline=$True,  
            ValueFromPipelineByPropertyName=$True, 
            Mandatory=$true, 
            HelpMessage= 'Enter the path to the target folder' 
            )] 
            [Alias("Fullname")] 
            [ValidateScript({Test-Path $_})] 
            [String[]]$Path, 
            # Set the unit of measure for the function, defaults to GB, acceptable values are GB, MB, and KB 
            [Parameter( 
            HelpMessage="Set the unit of measure for the function, defaults to GB, acceptable values are GB, MB, and KB")] 
            [ValidateSet('GB','MB','KB')] 
            [String]$Unit = 'GB' 
        ) 
    Begin  
        { 
            Write-Verbose "Setting unit of measure" 
            $value = Switch ($Unit) 
                { 
                    'GB' {1GB} 
                    'MB' {1MB} 
                    'KB' {1KB} 
                } 
        } 
    Process 
        { 
            Foreach ($FilePath in $Path) 
                { 
                    Try 
                        { 
                            Write-Verbose "Collecting Foldersize" 
                            $Size = Get-ChildItem $FilePath -Force -Recurse -ErrorAction Stop | Measure-Object -Property length -Sum 
                        } 
                    Catch 
                        { 
                            Write-Warning $_.Exception.Message 
                            $Problem = $True 
                        } 
                    If (-not($Problem)) 
                        { 
                            Try  
                                { 
                                    Write-Verbose "Creating Object" 
                                    New-Object -TypeName PSObject -Property @{ 
                                            FolderName = $FilePath 
                                            FolderSize = "$([math]::Round(($size.sum / $value), 2)) $($unit.toupper())" 
                                        } 
                                } 
                            Catch  
                                { 
                                    Write-Warning $_.Exception.Message 
                                    $Problem = $True 
                                } 
                        } 
                    if ($Problem) {$Problem = $false} 
                } 
        } 
    End{} 
    }

function Get-CleanableFolderSizes
    {
        $Global:path1 = "C:\WINDOWS\TEMP"
        $Global:Path2 = $ENV:TEMP
        $Global:foldersizes = Get-FolderSize -path $Global:path1, $Global:path2 -unit MB 
    }

##Function to Check for CBS log corruption
function Test-CBSLogCorruptionState
    {
        $cabfiles = get-childitem -Path $Global:Path1 -File cab_*
            if($($cabfiles.count) -gt 100)
                {
                    $Global:CBSCorruptionDetected = "CBS Log Corruption Detected"
                }
            else
                {
                    $Global:CBSCorruptionDetected = "No Corruption Detected"
                }
    }

##Function to Clean Large folders and CBS if flagged
function Invoke-FolderClean
    {
        foreach ($Folder in $($Global:foldersizes.FolderName))
            {
                $cleanPath = $Folder + "\"
                Remove-Item $cleanPath -Recurse
            }
        
        if ($Global:CBSCorruptionDetected -eq "CBS Log Corruption Detected")
            {
                Remove-Item C:\Windows\Logs\CBS\* -Recurse
            }
        $Global:foldersizesPostClean = Get-FolderSize -path $Global:path1, $Global:path2 -unit MB
    }
#Function to Output details to console for use in ticket notes
function Out-LTLog
    {
        $Global:DiskCleanupLog = "Checked folders, these are showing the following size details:"
        $Global:DiskCleanupLog += "`nFolderSize`tFolderName"
        $Global:DiskCleanupLog += "`n----------`t----------"
        foreach ($folder in $Global:foldersizes)
            {
                $Global:DiskCleanupLog += "`n" + $($folder.FolderSize) + "`t" + $($folder.FolderName)
            }
        $Global:DiskCleanupLog += "`n "
        $Global:DiskCleanupLog += "`nChecked for CBS log corruption, results:"
        $Global:DiskCleanupLog += "`n" + $Global:CBSCorruptionDetected
        $Global:DiskCleanupLog += "`n "
        $Global:DiskCleanupLog += "`nThe following folders will be purged:"
        $Global:DiskCleanupLog += "`n$Global:path1"
        $Global:DiskCleanupLog += "`n$Global:path2"
        if ($Global:CBSCorruptionDetected -eq "CBS Log Corruption Detected")
            {
                $Global:DiskCleanupLog += "`nC:\Windows\Logs\CBS"
            }
        $Global:DiskCleanupLog += "`n "
        $Global:DiskCleanupLog += "`nCleanup was run, these folders now report as follows:"
        $Global:DiskCleanupLog += "`nFolderSize`tFolderName"
        $Global:DiskCleanupLog += "`n----------`t----------"
        foreach ($folder in $Global:foldersizesPostClean)
            {
                $Global:DiskCleanupLog += "`n" + $($folder.FolderSize) + "`t" + $($folder.FolderName)
            }

        Write-Output $Global:DiskCleanupLog
    }