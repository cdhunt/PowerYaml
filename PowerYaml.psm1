. $PSScriptRoot\Functions\Casting.ps1
. $PSScriptRoot\Functions\Shadow-Copy.ps1
. $PSScriptRoot\Functions\YamlDotNet-Integration.ps1
. $PSScriptRoot\Functions\Validator-Functions.ps1
. $PSScriptRoot\Functions\New-ObjectFromGenericType.ps1

<# 
 .Synopsis
  Returns an object that can be dot navigated

 .Parameter FromFile
  File reference to a yaml document

 .Parameter FromString
  Yaml string to be converted
#>
function Get-Yaml([string] $FromString = "", [string] $FromFile = "") {
    if ($FromString -ne "") {
        $yaml = Get-YamlDocumentFromString $FromString
    } elseif ($FromFile -ne "") {
        if ((Validate-File $FromFile)) {
            $yaml = Get-YamlDocument -file $FromFile
        }
    }

    return Explode-Node $yaml.RootNode
}

function Import-Yaml {
	[CmdletBinding()]
	[OutputType([System.Object])]
	param(
		[Parameter(Position=0,Mandatory, ValueFromPipeline)]
		[ValidateScript( {if (Test-Path $PSItem -PathType Leaf) {$true} else {Throw "$PSItem does not exist"}} )]
		[System.String]
		$Path,
		
		[Parameter(Position=2, Mandatory)]
		[ValidateNotNullOrEmpty()]
		[Alias("Class")]
		[System.String]
		$Type		
	)
	try {
	
		$typeParams = @{ClassName = "YamlDotNet.RepresentationModel.Serialization.YamlSerializer"
						TypeName = $Type}
		
		$deserializer = New-ObjectFromGenericType @typeParams -ErrorAction Stop
		
		try
		{
			[IO.StringReader]$yamlStream = Get-Content -Path $Path -ErrorAction Stop | Out-String
		}
		catch 
		{
			Write-Error "Could not open $Path for reading"
			$_
		}
		
		return $deserializer.Deserialize($yamlStream)
	}
	catch {
		Write-Error "Could not load Generic YamlSerializer for $Type"
		$_
	}
}

Load-YamlDotNetLibraries (Join-Path $PSScriptRoot -ChildPath "Libs")
Export-ModuleMember -Function Get-Yaml, Import-Yaml 
