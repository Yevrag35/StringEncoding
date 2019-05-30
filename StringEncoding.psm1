Function Decode-String()
{
    [CmdletBinding(PositionalBinding=$false, DefaultParameterSetName='ByPipelineInput')]
    [Alias("decode", "decstr")]
    [OutputType([string])]
    param
    (
        [parameter(Mandatory, ValueFromPipeline, ParameterSetName="ByPipelineInput", DontShow)]
        [string] $InputObject,

        [parameter(Mandatory, Position = 0, ParameterSetName="BySpecificStrings")]
        [string[]] $EncodedString,

        [parameter(Mandatory = $false, Position = 0, ParameterSetName="ByPipelineInput")]
        [parameter(Mandatory = $false, Position = 1, ParameterSetName="BySpecificStrings")]
        [Alias("e", "en")]
        [ValidateSet("ASCII", "BigEndianUnicode", "Default", "Unicode", "UTF7", "UTF8", "UTF32")]
        [string] $Encoding = "Unicode"
    )
    Begin
    {
        [System.Text.Encoding]$RealEncoding = Resolve-Encoding -StrEncoding $Encoding;
        $list = New-Object -TypeName System.Collections.Generic.List[string];
    }
    Process
    {
        if ($PSBoundParameters.ContainsKey("InputObject"))
        {
            $list.Add($InputObject);
        }
        else
        {
            $list.AddRange($EncodedString);
        }
    }
    End
    {
        for ($i = 0; $i -lt $list.Count; $i++)
        {
            [byte[]]$backToBytes = [System.Convert]::FromBase64String($list[$i]);
            if ($null -ne $backToBytes -and $backToBytes.Length -gt 0)
            {
                $plainStr = $RealEncoding.GetString($backToBytes);
                Write-Output -InputObject $plainStr;
            }
        }
    }
}

Function Encode-String()
{
    [CmdletBinding(PositionalBinding=$false, DefaultParameterSetName="ByPipelineInput")]
    [Alias("encode", "encstr")]
    [OutputType([string])]
    param
    (
        [parameter(Mandatory, ValueFromPipeline, ParameterSetName="ByPipelineInput", DontShow)]
        [object] $InputObject,       # Multiple Pipeline objects will be coalesced into one 'encoded' string.

        [parameter(Mandatory, Position = 0, ParameterSetName="BySpecificObject")]
        [object[]] $Object,          # Multiple objects will be coalesced into one 'encoded' string.

        [parameter(Mandatory = $false, Position = 0, ParameterSetName="ByPipelineInput")]
        [parameter(Mandatory = $false, Position = 1, ParameterSetName="BySpecificObject")]
        [Alias("e", "en")]
        [ValidateSet("ASCII", "BigEndianUnicode", "Default", "Unicode", "UTF7", "UTF8", "UTF32")]
        [string] $Encoding = "Unicode"
    )
    Begin
    {
        [System.Text.Encoding]$RealEncoder = Resolve-Encoding -StrEncoding $Encoding;
        $list = New-Object -TypeName System.Collections.Generic.List[string];
    }
    Process
    {
        if ($PSBoundParameters.ContainsKey("InputObject"))
        {
            $list.AddRange([System.Collections.Generic.List[string]](Convert-Object -InputObject $InputObject));
        }
        else
        {
            $list.AddRange([System.Collections.Generic.List[string]]($Object | Convert-Object));
        }
    }
    End
    {
        $oneStr = [string]::Join([System.Environment]::NewLine, $list);
        [byte[]]$bytes = $RealEncoder.GetBytes($oneStr);
        $outStr = [System.Convert]::ToBase64String($bytes);
        Write-Output -InputObject $outStr;
    }
}

#region BACKEND FUNCTIONS
Function Convert-Object()
{
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[string]])]
    param
    (
        [parameter(Mandatory, Position=0, ValueFromPipeline)]
        [object] $InputObject
    )
    Begin
    {
        $throwMsg = "Cannot convert `$InputObject of type '{1}' to type 'System.String'.";
        $list = New-Object -TypeName System.Collections.Generic.List[string];
    }
    Process
    {
        if ($InputObject -is [string])
        {
            $list.Add([string]$InputObject);
        }
        elseif ($InputObject -is [System.ValueType])
        {
            $list.Add([System.Convert]::ToString($InputObject));
        }
        elseif ($InputObject -is [scriptblock])
        {
            $oneLine = $InputObject.ToString();
            [string[]]$allLines = $oneLine.Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries);
            $list.AddRange($allLines);
        }
        else
        {
            throw $($throwMsg -f $InputObject.GetType().FullName);
        }
    }
    End
    {
        Write-Output -InputObject $list -NoEnumerate;
    }
}

Function Resolve-Encoding()
{
    [CmdletBinding(PositionalBinding=$false)]
    [OutputType([System.Text.Encoding])]
    param
    (
        [parameter(Mandatory)]
        [string] $StrEncoding,

        [parameter(Mandatory=$false, DontShow)]
        [System.Reflection.BindingFlags] $Flags = [System.Reflection.BindingFlags]"Public,Static"
    )
    [type]$Type = [System.Text.Encoding];
    $Filter = { $_.PropertyType -eq $Type -and $_.Name -eq $StrEncoding };
    [System.Reflection.PropertyInfo]$property = $Type.GetProperties($Flags) | Where-Object $Filter;
    [System.Text.Encoding]$retEncoding = $property.GetValue($null);
    Write-Output -InputObject $retEncoding;
}

#endregion