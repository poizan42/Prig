# 
# File: Invoke-PilotStubber.ps1
# 
# Author: Akira Sugiura (urasandesu@gmail.com)
# 
# 
# Copyright (c) 2012 Akira Sugiura
#  
#  This software is MIT License.
#  
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
#

[CmdletBinding()]
param (
    [string[]]
    $ReferenceFrom, 

    [string]
    $Assembly, 

    [string]
    $AssemblyFrom, 

    [string]
    $TargetFrameworkVersion,

    [string]
    $KeyFile,

    [string]
    $OutputPath, 
    
    [Parameter(Mandatory = $True)]
    [string]
    $Settings, 
    
    [switch]
    $WhatIf
)

# -----------------------------------------------------------------------------------------------
#  
# Utilities
#  
# -----------------------------------------------------------------------------------------------
$ToRootNamespace = {
    param ($AssemblyInfo)
    $AssemblyInfo.GetName().Name + '.Prig'
}

$ToSignAssembly = {
    param ($KeyFile)
    if ([string]::IsNullOrEmpty($KeyFile)) {
        $false
    } else {
        $true
    }
}

$ToProcessorArchitectureConstant = {
    param ($AssemblyInfo)

    switch ($AssemblyInfo.GetName().ProcessorArchitecture)
    {
        'X86'       { "_M_IX86" }
        'Amd64'     { "_M_AMD64" }
        'MSIL'      { "_M_MSIL" }
        Default     { "_M_MSIL" }
    }
}

$ToTargetFrameworkVersionConstant = {
    param ($TargetFrameworkVersion)
    
    switch ($TargetFrameworkVersion)
    {
        'v3.5'      { "_NET_3_5" }
        'v4.0'      { "_NET_4" }
        'v4.5'      { "_NET_4_5" }
        'v4.5.1'    { "_NET_4_5_1" }
        Default     { "_NET_4" }
    }
}

$ToDefineConstants = {
    param ($AssemblyInfo, $TargetFrameworkVersion)
    $result = (& $ToProcessorArchitectureConstant $AssemblyInfo), (& $ToTargetFrameworkVersionConstant $TargetFrameworkVersion)
    $result -join ';'
}

$ToPlatformTarget = {
    param ($AssemblyInfo)

    switch ($AssemblyInfo.GetName().ProcessorArchitecture)
    {
        'X86'       { "x86" }
        'Amd64'     { "x64" }
        'MSIL'      { "AnyCPU" }
        Default     { "AnyCPU" }
    }
}

$ToProcessorArchitectureString = {
    param ($AssemblyInfo)

    switch ($AssemblyInfo.GetName().ProcessorArchitecture)
    {
        'X86'       { "x86" }
        'Amd64'     { "AMD64" }
        'MSIL'      { "MSIL" }
        Default     { "MSIL" }
    }
}

$ToAssemblyName = {
    param ($AssemblyInfo)
    '{0}.{1}.v{2}.{3}.Prig' -f $AssemblyInfo.GetName().Name, $AssemblyInfo.ImageRuntimeVersion, $AssemblyInfo.GetName().Version.ToString(), (& $ToProcessorArchitectureString $AssemblyInfo)
}

$ToReferenceInclude = {
    param ($refAsmInfos)
    
    foreach ($refAsmInfo in $refAsmInfos) {
        @"
        <Reference Include="$($refAsmInfo.GetName().Name)">
            <HintPath>$($refAsmInfo.Location)</HintPath>
        </Reference>
"@
    }
}

$GenerateCsproj = {
    param ($WorkDirectory, $AssemblyInfo, $ReferencedAssemblyInfos, $KeyFile, $TargetFrameworkVersion, $OutputPath)

    $rootNamespace = & $ToRootNamespace $AssemblyInfo
    $signAsm = & $ToSignAssembly $KeyFile
    $defineConsts = & $ToDefineConstants $AssemblyInfo $TargetFrameworkVersion
    $platform = & $ToPlatformTarget $AssemblyInfo
    $asmName = & $ToAssemblyName $AssemblyInfo
    $refInc = & $ToReferenceInclude $ReferencedAssemblyInfos

    $csprojTemplate = [xml]@"
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="4.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <PropertyGroup>
        <OutputType>Library</OutputType>
        <RootNamespace>$rootNamespace</RootNamespace>
        <FileAlignment>512</FileAlignment>
        <SignAssembly>$signAsm</SignAssembly>
        <AssemblyOriginatorKeyFile>$KeyFile</AssemblyOriginatorKeyFile>
        <OutputPath>$OutputPath</OutputPath>
        <DefineConstants>$defineConsts</DefineConstants>
        <PlatformTarget>$platform</PlatformTarget>
        <DebugType>pdbonly</DebugType>
        <Optimize>true</Optimize>
        <TargetFrameworkVersion>$TargetFrameworkVersion</TargetFrameworkVersion>
        <AssemblyName>$asmName</AssemblyName>
    </PropertyGroup>
    <ItemGroup>$refInc</ItemGroup>
    <ItemGroup>
        <Compile Include="**/*.cs" />
    </ItemGroup>
    <Import Project="`$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
</Project>
"@

    New-Object psobject | 
        Add-Member NoteProperty 'Path' ([System.IO.Path]::Combine($WorkDirectory, "$rootNamespace.g.csproj")) -PassThru | 
        Add-Member NoteProperty 'XmlDocument' $csprojTemplate -PassThru
}

$ToFullNameFromType = {
    param ($Type)
    
    $defName = $Type.FullName
    
    if ($Type.IsGenericType -and !$Type.IsGenericTypeDefinition)
    {
        $defName = $Type.Namespace + "." + $Type.Name
    } elseif ($Type.ContainsGenericParameters) {
        $defName = $Type.Name
    }

    if ($Type.IsGenericType) {
        $defName = $defName -replace '`\d+', ''
        $genericArgNames = @()
        foreach ($genericArg in $Type.GetGenericArguments()) {
            $genericArgNames += (& $ToFullNameFromType $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }

    $defName
}

$ToClassNameFromType = {
    param ($Type)
    $defName = $Type.Name
    if ($Type.IsGenericType) {
        $defName = $defName -replace '`\d+', ''
        $genericArgNames = @()
        foreach ($genericArg in $Type.GetGenericArguments()) {
            $genericArgNames += (& $ToFullNameFromType $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }
    $defName
}

$ToBaseNameFromType = {
    param ($Type)
    $defName = $Type.Name
    if ($Type.IsGenericType) {
        $defName = $defName -replace '`\d+', ''
    }
    $defName + "Base"
}

$ToClassNameFromStub = {
    param ($Stub)
    $defName = $Stub.Alias
    if ($Stub.Target.IsGenericMethod) {
        $defName = $defName -replace '`\d+', ''
        $genericArgNames = @()
        foreach ($genericArg in $Stub.Target.GetGenericArguments()) {
            $genericArgNames += (& $ToFullNameFromType $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }
    $defName
}

$GenerateTokensCs = {
    param ($WorkDirectory, $AssemblyInfo, $Section, $TargetFrameworkVersion)

    $content = @"
#if $(& $ToTargetFrameworkVersionConstant $TargetFrameworkVersion) && $(& $ToProcessorArchitectureConstant $AssemblyInfo)
//------------------------------------------------------------------------------ 
// <auto-generated> 
// This code was generated by a tool. 
// Assembly                 : $($AssemblyInfo.GetName().Name)
// Runtime Version          : $($AssemblyInfo.ImageRuntimeVersion)
// Assembly Version         : $($AssemblyInfo.GetName().Version.ToString())
// Processor Architecture   : $(& $ToProcessorArchitectureString $AssemblyInfo)
// 
// Changes to this file may cause incorrect behavior and will be lost if 
// the code is regenerated. 
// </auto-generated> 
//------------------------------------------------------------------------------


using Urasandesu.Prig.Framework;

"@ + $(foreach ($stub in $Section.Stubs) {
@"

[assembly: Indirectable($($stub.Target.DeclaringType.Namespace).Prig.P$(& $ToBaseNameFromType $stub.Target.DeclaringType).TokenOf$($stub.Name))]
"@}) + @"
"@ + $(foreach ($namespaceGrouped in $Section.GroupedStubs) {
@"


namespace $($namespaceGrouped.Key).Prig
{
"@ + $(foreach ($declTypeGrouped in $namespaceGrouped) {
@"

    public abstract class P$(& $ToBaseNameFromType $declTypeGrouped.Key)
    {
"@ + $(foreach ($stub in $declTypeGrouped) {
@"

        internal const int TokenOf$($stub.Name) = 0x$($stub.Target.MetadataToken.ToString('X8'));
"@}) + @"

    }
"@}) + @"

}
"@}) + @"

#endif
"@
    
    New-Object psobject | 
        Add-Member NoteProperty 'Path' ([System.IO.Path]::Combine($WorkDirectory, 'AutoGen\Tokens.g.cs')) -PassThru | 
        Add-Member NoteProperty 'Content' $content -PassThru
}

$GenerateStubsCs = {
    param ($WorkDirectory, $AssemblyInfo, $Section, $TargetFrameworkVersion)

    $results = New-Object System.Collections.ArrayList
    
    foreach ($namespaceGrouped in $Section.GroupedStubs) {
        $dir = $namespaceGrouped.Key -replace '\.', '\'

        foreach ($declTypeGrouped in $namespaceGrouped) {
            $content = @"

using Urasandesu.Prig.Framework;

namespace $($namespaceGrouped.Key).Prig
{
    public class P$(& $ToClassNameFromType $declTypeGrouped.Key) : P$(& $ToBaseNameFromType $declTypeGrouped.Key)
    {
"@ + $(foreach ($stub in $declTypeGrouped) {
@"

        public static class $(& $ToClassNameFromStub $stub)
        {
            public static $(& $ToClassNameFromType $stub.IndirectionDelegate) Body
            {
                set
                {
                    var info = new IndirectionInfo();
                    info.AssemblyName = "$($AssemblyInfo.FullName)";
                    info.Token = TokenOf$($stub.Name);
                    var holder = LooseCrossDomainAccessor.GetOrRegister<IndirectionHolder<$(& $ToClassNameFromType $stub.IndirectionDelegate)>>();
                    holder.AddOrUpdate(info, value);
                }
            }
        }
"@}) + @"

    }
}
"@
            $result = 
                New-Object psobject | 
                    Add-Member NoteProperty 'Path' ([System.IO.Path]::Combine($WorkDirectory, "$dir\$($declTypeGrouped.Key.Name).cs")) -PassThru | 
                    Add-Member NoteProperty 'Content' $content -PassThru
            [Void]$results.Add($result)
        }
    }

    ,$results
}



# -----------------------------------------------------------------------------------------------
#  
# Main
#  
# -----------------------------------------------------------------------------------------------
Write-Verbose ('ReferenceFrom            : {0}' -f $ReferenceFrom)
Write-Verbose ('Assembly                 : {0}' -f $Assembly)
Write-Verbose ('Target Framework Version : {0}' -f $TargetFrameworkVersion)
Write-Verbose ('Key File                 : {0}' -f $KeyFile)
Write-Verbose ('Output Path              : {0}' -f $OutputPath)
Write-Verbose ('Settings                 : {0}' -f $Settings)

Write-Verbose 'Load Settings ...'
[Void][System.Reflection.Assembly]::LoadWithPartialName('System.Configuration')

if (![string]::IsNullOrEmpty($Assembly)) {
    $asmInfo = [System.Reflection.Assembly]::Load($Assembly)
} elseif (![string]::IsNullOrEmpty($AssemblyFrom)) {
    $asmInfo = [System.Reflection.Assembly]::LoadFrom($AssemblyFrom)
}
if ($null -eq $asmInfo) {
    throw New-Object System.Management.Automation.ParameterBindingException 'The parameter ''Assembly'' or ''AssemblyFrom'' is mandatory.'
}
 
$refAsmInfos = New-Object 'System.Collections.Generic.List[System.Reflection.Assembly]'
foreach ($refFrom in $ReferenceFrom) {
    $refAsmInfos.Add([System.Reflection.Assembly]::LoadFrom($refFrom))
}
$refAsmInfos.Add($asmInfo)

$onAsmInfoResolve = [System.ResolveEventHandler] {
    param($Sender, $E)
    foreach($curAsmInfo in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
        if ($curAsmInfo.FullName -match $E.Name) {
            return $curAsmInfo
        }
    }
    return $null
}

[System.AppDomain]::CurrentDomain.add_AssemblyResolve($onAsmInfoResolve)

$fileMap = New-Object System.Configuration.ExeConfigurationFileMap
$fileMap.ExeConfigFilename = $Settings
$config = [System.Configuration.ConfigurationManager]::OpenMappedExeConfiguration($fileMap, [System.Configuration.ConfigurationUserLevel]::None)
$section = $config.GetSection("prig")

$workDir = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($Settings), (& $ToAssemblyName $asmInfo))
if (![string]::IsNullOrEmpty($workDir) -and ![IO.Directory]::Exists($workDir)) {
    New-Item $workDir -ItemType Directory -WhatIf:$WhatIf -ErrorAction Stop | Out-Null
}


Write-Verbose 'Generate Tokens.g.cs ...'
$tokensCsInfo = & $GenerateTokensCs $workDir $asmInfo $section $TargetFrameworkVersion
$tokensCsDir = [System.IO.Path]::GetDirectoryName($tokensCsInfo.Path)
if (![string]::IsNullOrEmpty($tokensCsDir) -and ![IO.Directory]::Exists($tokensCsDir)) {
    New-Item $tokensCsDir -ItemType Directory -WhatIf:$WhatIf -ErrorAction Stop | Out-Null
}
$tokensCsInfo.Content | Out-File $tokensCsInfo.Path -Encoding utf8 -WhatIf:$WhatIf -ErrorAction Stop | Out-Null


Write-Verbose 'Generate stubs *.cs ...'
$stubsCsInfos = & $GenerateStubsCs $workDir $asmInfo $section $TargetFrameworkVersion
foreach ($stubsCsInfo in $stubsCsInfos) {
    $stubsCsDir = [System.IO.Path]::GetDirectoryName($stubsCsInfo.Path)
    if (![string]::IsNullOrEmpty($stubsCsDir) -and ![IO.Directory]::Exists($stubsCsDir)) {
        New-Item $stubsCsDir -ItemType Directory -WhatIf:$WhatIf -ErrorAction Stop | Out-Null
    }
    if (![System.IO.File]::Exists($stubsCsInfo.Path)) {
        $stubsCsInfo.Content | Out-File $stubsCsInfo.Path -Encoding utf8 -WhatIf:$WhatIf -ErrorAction Stop | Out-Null
    }
}


Write-Verbose 'Generate *.csproj ...'
$csprojInfo = & $GenerateCsproj $workDir $asmInfo $refAsmInfos $KeyFile $TargetFrameworkVersion $OutputPath
$csprojDir = [System.IO.Path]::GetDirectoryName($csprojInfo.Path)
if (![string]::IsNullOrEmpty($csprojDir) -and ![IO.Directory]::Exists($csprojDir)) {
    New-Item $csprojDir -ItemType Directory -WhatIf:$WhatIf -ErrorAction Stop | Out-Null
}
$csprojInfo.XmlDocument.Save($csprojInfo.Path)


Write-Verbose 'Build all *.cs files ...'
& msbuild $csprojInfo.Path /t:rebuild
