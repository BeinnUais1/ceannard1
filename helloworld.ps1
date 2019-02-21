$packs = Find-PackageProvider
If(!($packs.Name -clike 'nuget'))
{
	Install-PackageProvider -Name NuGet -scope CurrentUser -Force
}

$mods = Get-InstalledModule
If(!($mods.Name -clike 'PowerShellForGitHub'))
{
	Install-Module -Name PowerShellForGithub -Scope CurrentUser -Force
}

echo $mods.Name > C:\Users\$env:UserName\Desktop\hello.txt