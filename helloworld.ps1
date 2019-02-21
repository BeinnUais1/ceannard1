$packs = Get-PackageProvider
If(!($packs.Name -clike 'NuGet'))
{
	Install-PackageProvider -Name NuGet -scope CurrentUser -Force
}
$packs = Get-PackageProvider
If(!($packs.Name -clike 'NuGet'))
{
	echo "ERROR: Unable to install NuGet."
}
ElseIf($packs.Name -clike 'NuGet')
{
	echo "NuGet installed Ok."
}

$mods = Get-InstalledModule
If(!($mods.Name -clike 'PowerShellForGitHub'))
{
	Install-Module -Name PowerShellForGithub -Scope CurrentUser -Force
}
$mods = Get-InstalledModule
If(!($mods.Name -clike 'PowerShellForGitHub'))
{
	echo "ERROR: Unable to install PSFG."
}
ElseIf($mods.Name -clike 'PowerShellForGitHub')
{
	echo "PSFG installed Ok."
}

Set-GitHubConfiguration -DisableTelemetry -SessionOnly
$tkn = 'ffbc' + 'f7ac0f2e' + '9b703fcfd17e4f' + 'ab4104269e81ad'
$secure = ConvertTo-SecureString $tkn -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential "USERNAME_IS_IGNORED", $secure
Set-GitHubAuthentication -Credential $cred
Get-GitHubUser -Current

echo $mods.Name > C:\Users\$env:UserName\Desktop\hello.txt