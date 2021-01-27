<#
.Synopsis
   This script is designed to backup a given directory to a given folder as a compressed archive and will 
   delete the oldest existing file in the directory if the file count is greater than or equal to the user 
   set backup retention number.
.DESCRIPTION
   This script is designed to backup a given directory to a dedicated folder. The source folder will be 
   compressed to a zip file and appended with the current date and time stamp down to the second. The user 
   will supply a number of backups to retain as this is designed to be run on a schedule. If the number of
   files in the dedicated backup folder equals or exceeds the number set in the retention argument, then
   the script will delete files in the backup directory until the file count is 1 less than the retention
   value, starting with the oldest file. The project name parameter is used as the base for the archive
   name and should reflect the source in some way.
.NOTES
   Version:                 1.0
   Author:                  Jackson T. Eyton
   Creation Date:           2021/01/27
.EXAMPLE
   TM1Backups.ps1 -SourceDirectory D:\Folder\Path\Data\ -DestinationDirectory D:\Folder\Path\Backups\ -BackupRetention 14 -ProjectName MyDataProject
#>

##This file should accept CLI parameter arguments to
##specify the directory to backup, the path to store
##the backups, the project name (base filename), and
##the number of backup retentions.
param 
    (
        [Parameter(Mandatory)]$SourceDirectory, 
        [Parameter(Mandatory)]$DestinationDirectory, 
        $BackupRetention=1, 
        [Parameter(Mandatory)]$ProjectName
    )

Function New-Backup ($SourceDirectory, $DestinationDirectory, $BackupRetention, $ProjectName)
    {
        #count num of existing backups to variable
        $fileCount = ( Get-ChildItem $DestinationDirectory | Measure-Object ).Count

        #Loop while file count -ge $Retention delete oldest file
        while ($fileCount -ge $BackupRetention)
            {
                Get-ChildItem $DestinationDirectory | Sort-Object CreationTime | Select-Object -First 1 | Remove-Item
                $fileCount = ( Get-ChildItem $DestinationDirectory | Measure-Object ).Count
            }

        #Create new backup using $ProjeName+DateTime
        $BackupName = $DestinationDirectory + $ProjectName +'_'+ (get-date -f yyyy-MM-dd-HH-mm-ss)
        Compress-Archive -Path $SourceDirectory -DestinationPath $BackupName -CompressionLevel Optimal
    }

New-Backup -SourceDirectory $SourceDirectory -DestinationDirectory $DestinationDirectory -BackupRetention $BackupRetention -ProjectName $ProjectName
