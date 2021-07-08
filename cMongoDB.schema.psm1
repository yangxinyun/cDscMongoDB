Configuration cMongoDB
{
    param(
        [Parameter(Mandatory = $True)]
        [ValidateSet('Present', 'Absent')] 
        [string] $Ensure,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()] 
        [System.IO.FileInfo] $MongoSourcePath,

        [ValidateNotNullOrEmpty()] 
        [System.IO.FileInfo] $ConfigFile = "$env:ProgramFiles\MongoDb\Server\3.4\mongod.cfg",

        [ValidateNotNullOrEmpty()] 
        [System.IO.FileInfo] $DBFolder = "d:\data\mongo-db",

        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $LogFolder = "d:\data\mongo-log",

        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $MongoExe = "$env:ProgramFiles\MongoDB\Server\3.4\bin\mongod.exe"
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Package InstallMongoDb
    {
        Ensure    = $Ensure
        Name      = 'MongoDB 3.4.4 2008R2Plus (64 bit)'
        Path      = $MongoSourcePath
        ProductId = '5582AB82-490A-4790-81F3-94D649925A1F'

    }

    File ConfigurationFile 
    {
        Ensure          = $Ensure
        Type            = "File"
        DestinationPath = $ConfigFile
        #Do not change the format of Contents part, the format matters!
        Contents        = 
        "
systemLog:
    destination: file
    path: $LogFolder\mongod.log
storage:
    dbPath: $DBFolder
"
        Force           = $true
    }
    

    File DBDir
    {   
        Ensure          = $Ensure
        Type            = "Directory"
        DestinationPath = $DBFolder
        Force           = $true
    }

    File LogDir
    {
        Ensure          = $Ensure
        Type            = "Directory"
        DestinationPath = $LogFolder
        Force           = $true
    }

    Script InstallMongoService
    {
        DependsOn  = "[package]InstallMongoDb", "[file]ConfigurationFile", "[file]DBDir", "[file]LogDir"
        GetScript  =
        {
            $instances = Get-Service mongoDB* #Get-WmiObject win32_service | Where-Object { $_.Name -match "mongo*" -and $_.PathName -match "mongod.exe" } | ForEach-Object { $_.Caption }
            $vals = @{ 
                Installed = [boolean]$instances; 
            }
            return $vals
        }
        TestScript =
        {
            $instances = Get-Service mongoDB* #Get-WmiObject win32_service | Where-Object { $_.Name -match "mongo*" -and $_.PathName -match "mongod.exe" } | ForEach-Object { $_.Caption }
            if ($instances)
            {
                Write-Verbose "MongoDB is already running as a service"
            }
            else
            {
                Write-Verbose "MongoDB is not running as a service"
            }
            return [boolean]$instances
        }
        SetScript  =
        {   
            if ($using:Ensure -eq 'Present' -and ![boolean](Get-Service mongoDB*))
            {
                $process = Start-Process -FilePath $using:mongoExe -ArgumentList "--config `"$using:configFile`" --install" -PassThru

                Start-Sleep -Seconds 10
                if ($process.ExitCode -ne 0)
                {
                    Write-Error "Mongo DB Service installation completed with errors (exit code $($process.ExitCode))"
                }
                else
                {
                    Write-Verbose "Mongo DB Service installation completed successfully (exit code $($process.ExitCode))"
                }
            }
            elseif ($using:Ensure -eq 'Absent' -and (Test-Path $using:mongoExe))
            {
                $process = Start-Process -FilePath $using:mongoExe -ArgumentList "--remove" -PassThru
                Start-Sleep -Seconds 10
                if ($process.ExitCode -ne 0)
                {
                    Write-Error "Mongo DB Service Removal completed with errors (exit code $($process.ExitCode))"
                }
                else
                {
                    Write-Verbose "Mongo DB Service completed successfully (exit code $($process.ExitCode))"
                }
            }
        }
    }

    Service StartMongoService
    {
        Ensure      = $Ensure
        DependsOn   = "[script]InstallMongoService"
        StartupType = "Automatic"
        Name        = "MongoDB"
        State       = "Running"
    }
    
}