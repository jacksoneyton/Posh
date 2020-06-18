new-module -scriptblock {
 function splitter {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$inputpath,
    [Parameter(Mandatory=$True,Position=2)]
    [string]$inputfile
       )
  $src=  join-path -path $inputpath -childpath $inputfile
  $fileName = $inputfile.Split(".")[0]
  $splitpath= join-path -path $inputpath -childpath $fileName + "_Split - {0}.csv"
  # Read in source file and grab header row.
  $inData = New-Object -TypeName System.IO.StreamReader -ArgumentList $src
  $header = $inData.ReadLine()

  # Create initial output object
  $outData = New-Object -TypeName System.Text.StringBuilder
  [void]$outData.Append($header)

  $i = 0

  while( $line = $inData.ReadLine() ){
    # If the object is longer than 100MB then output the content of the object and create a new one.
    if( $outData.Length -gt 100MB ){
        $outData.ToString() | Out-File -FilePath ( $SplitPath -f $i ) -Encoding ascii
        
        $outData = New-Object -TypeName System.Text.StringBuilder
        [void]$outData.Append($header)

        $i++
        }
    
    Write-Verbose "$currentFile, $line"
    
    [void]$outData.Append("`r`n$($line)")
    }new-module -scriptblock {
 function splitter {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$inputpath,
    [Parameter(Mandatory=$True,Position=2)]
    [string]$inputfile
       )
  $src=  join-path -path $inputpath -childpath $inputfile    
  $splitpath= join-path -path $inputpath -childpath "Split - {0}.csv"
  # Read in source file and grab header row.
  $inData = New-Object -TypeName System.IO.StreamReader -ArgumentList $src
  $header = $inData.ReadLine()

  # Create initial output object
  $outData = New-Object -TypeName System.Text.StringBuilder
  [void]$outData.Append($header)

  $i = 0

  while( $line = $inData.ReadLine() ){
    # If the object is longer than 600MB then output the content of the object and create a new one.
    if( $outData.Length -gt 95MB ){
        $outData.ToString() | Out-File -FilePath ( $SplitPath -f $i ) -Encoding ascii
        
        $outData = New-Object -TypeName System.Text.StringBuilder
        [void]$outData.Append($header)

        $i++
        }
    
    Write-Verbose "$currentFile, $line"
    
    [void]$outData.Append("`r`n$($line)")
    }

  # Write contents of final object 
  $outData.ToString() | Out-File -FilePath ( $SplitPath -f $i ) -Encoding ascii
   }
 }

  # Write contents of final object 
  $outData.ToString() | Out-File -FilePath ( $SplitPath -f $i ) -Encoding ascii
   }
 }
