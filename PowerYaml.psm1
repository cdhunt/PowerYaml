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
		[ValidateScript({ if (Test-Path $PSItem -PathType Leaf) {$true} else {Throw "$PSItem does not exist."} })]
		[System.String]
		$Path,
		
		[Parameter(Position=2, Mandatory)]
		[ValidateScript({ if (($PSItem -as [Type]) -ne $null) {$true} else {Throw "$Type is not available in the current sesson."} })]
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
			Write-Error "Could not open $Path for reading. $($_.Exception.Message)"
		}
		
		return $deserializer.Deserialize($yamlStream)
	}
	catch {
		Write-Error "Could not load Generic YamlSerializer for $Type. $($_.Exception.Message)"
	}
}

function Export-Yaml {
	[CmdletBinding()]
	[OutputType([System.IO.FileInfo])]
	param(
		[Parameter(Mandatory, ValueFromPipeline)]
		[System.Object]
		$InputObject,
		
		[Parameter(Position=1, Mandatory)]
		[ValidateScript({ if (Test-Path $PSItem -IsValid) {$true} else {Throw "$PSItem is not a valid path."} })]
		[System.String]
		$Path,
		
		[Parameter(Position=2)]
		[Switch]
		$Force
	)
	
	Begin
	{
	
		$typeParams = @{ClassName = "System.Collections.Generic.List"
						TypeName = $obj.GetType()}
		
		$deserializer = New-ObjectFromGenericType @typeParams -ErrorAction Stop
		$accumulator = @()
		$serializationOptions = [YamlDotNet.RepresentationModel.Serialization.SerializationOptions]::Roundtrip		
		
		$fileMode = [IO.FileMode]::Create
		$fileAccess = [IO.FileAccess]::Write
	}
	
	Process
	{
		Foreach ($obj in $InputObject)
		{
			$obj | gm
			$accumulator += $obj
		}	
	}
	
	End
	{		
		Write-Output $accumulator
		try {
			$serializer = New-Object YamlDotNet.RepresentationModel.Serialization.Serializer
			$fileStream = New-Object IO.FileStream $Path, $fileMode, $fileAccess
			$streamWriter = New-Object IO.StreamWriter($fileStream, [Text.Encoding]::UTF8)
			
			$serializer.Serialize($streamWriter, $accumulator, $serializationOptions)
			
			Get-Item $Path
		}
		catch {
			Write-Error "Could not serialize object. $_.Exception.Message"
			$_
		}
		finally
		{
			$streamWriter.Close()
			$fileStream.Close()
		}
	}
}
Add-Type -Path "$PSScriptRoot\Libs\YamlDotNet.RepresentationModel.dll"
#Load-YamlDotNetLibraries (Join-Path $PSScriptRoot -ChildPath "Libs")
Export-ModuleMember -Function Get-Yaml, Import-Yaml, Export-Yaml
