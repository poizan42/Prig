# 
# File: NuGet.Get-IndirectionStubSetting.ps1
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

function Get-IndirectionStubSetting {

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [System.Reflection.MethodBase[]]
        $InputObject
    )

    begin {
        [Void][System.Reflection.Assembly]::LoadWithPartialName('System.Runtime.Serialization')
    } process {
        if ($null -ne $InputObject) {
            foreach ($methodBase in $InputObject) {
                $ndcs = New-Object System.Runtime.Serialization.NetDataContractSerializer
                $sb = New-Object System.Text.StringBuilder
                $sw = New-Object System.IO.StringWriter $sb
                try {
                    $xw = New-Object System.Xml.XmlTextWriter $sw
                    $xw.Formatting = [System.Xml.Formatting]::Indented
                    $ndcs.WriteObject($xw, $methodBase);
                } finally {
                    if ($null -ne $xw) { $xw.Close() }
                }

                $content = $sb.ToString() -replace ', Version=\d+\.\d+\.\d+\.\d+, Culture=[^,]+, PublicKeyToken=[^<]+', ''
                $name = ConvertToIndirectionStubName $methodBase
                @"
<add name="$name" alias="$name">
$content
</add>

"@
            }
        }
    } end {

    }
}

New-Alias PGet Get-IndirectionStubSetting
