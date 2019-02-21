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

echo $mods.Name > C:\Users\$env:UserName\Desktop\hello.txt
