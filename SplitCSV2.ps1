# Set the input and output file paths
$inputFile = 'C:\path\to\input.csv'
$outputFile = 'C:\path\to\output_'

# Set the maximum size of the output files (in bytes)
$maxSize = 4 * 1024 * 1024

# Initialize the output file counter
$fileCounter = 1

# Open the input file for reading
$reader = New-Object System.IO.StreamReader($inputFile)

# Create the first output file
$writer = New-Object System.IO.StreamWriter("$outputFile$fileCounter.csv")

# Read the input file line by line
while (($line = $reader.ReadLine()) -ne $null) {
    # Check if the output file has reached the maximum size
    if ($writer.BaseStream.Length -gt $maxSize) {
        # Close the current output file
        $writer.Close()

        # Increment the output file counter
        $fileCounter++

        # Create a new output file
        $writer = New-Object System.IO.StreamWriter("$outputFile$fileCounter.csv")
    }

    # Write the current line to the output file
    $writer.WriteLine($line)
}

# Close the last output file
$writer.Close()

# Close the input file
$reader.Close()
