function Test-SQLServerConnection {
    param (
        [string]$ServerInstance,
        [string]$Database,
        [string]$Username,
        [string]$Password
    )

    # Load the necessary assembly
    Add-Type -AssemblyName "System.Data"

    # Define the connection string
    $connectionString = "Server=$ServerInstance;Database=$Database;User Id=$Username;Password=$Password;"

    # Create a new SQL connection
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString

    try {
        # Open the connection
        $connection.Open()
        Write-Host "Connection to $ServerInstance established successfully."
        
        # Perform your SQL operations here
        # For example, to execute a simple query:
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT GETDATE()"
        $reader = $command.ExecuteReader()

        while ($reader.Read()) {
            Write-Host "Current date and time: " $reader[0]
        }
        $reader.Close()
    }
    catch {
        Write-Host "An error occurred: " $_.Exception.Message
    }
    finally {
        # Close the connection
        $connection.Close()
        Write-Host "Connection to $ServerInstance closed."
    }
}
