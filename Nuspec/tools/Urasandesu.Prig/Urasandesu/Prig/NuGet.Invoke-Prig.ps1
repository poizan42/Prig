# 
# File: NuGet.Invoke-Prig.ps1
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



function Invoke-Prig {

    [CmdletBinding(DefaultParametersetName = 'Runner')]
    param (
        [Parameter(Position = 0)]
        [ValidateSet("", "run", "dasm")] 
        [string]
        $Mode, 

        [switch]
        $Help, 

        [Alias("p")]
        [Parameter(ParameterSetName = 'Runner')]
        [string]
        $Process, 

        [Alias("a")]
        [Parameter(ParameterSetName = 'Runner')]
        [string]
        $Arguments, 

        [Parameter(ParameterSetName = 'DisassemblerWithAssembly')]
        [string]
        $Assembly, 

        [Parameter(ParameterSetName = 'DisassemblerWithAssemblyFrom')]
        [string]
        $AssemblyFrom
    )

    $prigPkg = Get-Package Prig
    $prigPkgName = $prigPkg.Id + '.' + $prigPkg.Version

    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.Build')
    $msbProjCollection = [Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection
    $envProj = (Get-Project).Object.Project
    $allMsbProjs = $msbProjCollection.GetLoadedProjects($envProj.FullName).GetEnumerator()
    if(!$allMsbProjs.MoveNext()) {
        throw New-Object System.InvalidOperationException ('"{0}" has not been loaded.' -f $envProj.FullName)
    }

    $curMsbProj = $allMsbProjs.Current
    $solutionDir = $curMsbProj.ExpandString('$(SolutionDir)')
    $prig = $solutionDir + ('packages\{0}\tools\prig.exe' -f $prigPkgName)
    
    if ([string]::IsNullOrEmpty($Mode) -and $Help) {
        & $prig -help
    } elseif (![string]::IsNullOrEmpty($Mode) -and $Help) {
        & $prig $Mode -help
    } else {
        switch ($PsCmdlet.ParameterSetName) {
            'Runner' { 
                if ([string]::IsNullOrEmpty($Arguments)) {
                    & $prig run -process $Process
                } else {
                    & $prig run -process $Process -arguments $Arguments 
                }
            }
            'DisassemblerWithAssembly' { 
                & $prig dasm -assembly $Assembly
            }
            'DisassemblerWithAssemblyFrom' { 
                & $prig dasm -assemblyfrom $AssemblyFrom
            }
        }
    }
}

New-Alias prig Invoke-Prig
