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
        $Global:Path2 = (Get-ChildItem -path C:\Users\*\AppData\Local\Temp)
        $Global:foldersizes1 = Get-FolderSize -path $Global:path1 -unit MB 
        $Global:foldersizes2 = Get-FolderSize -path $Global:path2 -unit MB
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
        Test-CBSLogCorruptionState
        foreach ($Folder in $($Global:foldersizes1.FolderName))
            {
                $cleanPath = $Folder + "\*"
                Remove-Item $cleanPath -Recurse
            }

        foreach ($Folder in $($Global:foldersizes2.FolderName))
            {
                $cleanPath = $Folder + "\*"
                Remove-Item $cleanPath -Recurse
            }            
            
        if ($Global:CBSCorruptionDetected -eq "CBS Log Corruption Detected")
            {
                Remove-Item C:\Windows\Logs\CBS\* -Recurse
            }
        $Global:foldersizes1PostClean = Get-FolderSize -path $Global:path1 -unit MB
        $Global:foldersizes2PostClean = Get-FolderSize -path $Global:path2 -unit MB
    }
#Function to Output details to console for use in ticket notes
function Out-LTLog
    {
        Write-Output "Checked folders, these are showing the following size details:" $Global:foldersizes1 $Global:foldersizes2
                        
        Write-Output ""
        Write-Output "Checked for CBS log corruption, results:"
        Write-Output "$Global:CBSCorruptionDetected"
        Write-Output ""
        Write-Output "The following folders will be purged:"
        Write-Output $Global:foldersizes1.FolderName
        Write-Output $Global:foldersizes2.FolderName
        if ($Global:CBSCorruptionDetected -eq "CBS Log Corruption Detected")
            {
                Write-Output "C:\Windows\Logs\CBS"
            }

        Write-Output ""
        Write-Output "Cleanup was run, these folders now report as follows:" $Global:foldersizes1PostClean $Global:foldersizes2PostClean | ft
    }
