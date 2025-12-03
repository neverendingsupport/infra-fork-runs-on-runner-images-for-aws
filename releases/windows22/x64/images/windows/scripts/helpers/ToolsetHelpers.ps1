function Merge-ToolsetObject {
    Param(
        [Parameter(Mandatory = $true)]
        [object] $Base,

        [Parameter()]
        [AllowNull()]
        [object] $Override
    )

    if ($null -eq $Override) {
        return $Base
    }

    if ($null -eq $Base) {
        return $Override
    }

    $baseIsDictionary = $Base -is [System.Collections.IDictionary]
    $overrideIsDictionary = $Override -is [System.Collections.IDictionary]
    $baseIsObject = $baseIsDictionary -or ($Base -is [System.Management.Automation.PSCustomObject])
    $overrideIsObject = $overrideIsDictionary -or ($Override -is [System.Management.Automation.PSCustomObject])

    if (($Base -is [System.Collections.IList]) -and ($Override -is [System.Collections.IList])) {
        return @($Base + $Override)
    }

    if ($baseIsObject -and $overrideIsObject) {
        $baseKeys = if ($baseIsDictionary) { $Base.Keys } else { ($Base | Get-Member -MemberType NoteProperty).Name }
        $overrideKeys = if ($overrideIsDictionary) { $Override.Keys } else { ($Override | Get-Member -MemberType NoteProperty).Name }
        $allKeys = @($baseKeys + $overrideKeys) | Sort-Object -Unique

        $merged = @{}
        foreach ($key in $allKeys) {
            $baseValue = if ($baseIsDictionary) { $Base[$key] } else { $Base.$key }
            $overrideValue = if ($overrideIsDictionary) { $Override[$key] } else { $Override.$key }

            $merged[$key] = if (($baseKeys -contains $key) -and ($overrideKeys -contains $key)) {
                Merge-ToolsetObject -Base $baseValue -Override $overrideValue
            } elseif ($overrideKeys -contains $key) {
                $overrideValue
            } else {
                $baseValue
            }
        }

        return [pscustomobject]$merged
    }

    return $Override
}
