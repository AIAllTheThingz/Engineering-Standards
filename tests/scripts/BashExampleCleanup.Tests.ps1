BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:wrapper = Get-Content -LiteralPath (Join-Path $script:root 'examples/bash-project/tools/Test-Example.ps1') -Raw
}

Describe 'Bash example temporary cleanup' {
    It 'restores owner access before removing sandbox output' {
        $chmodIndex = $script:wrapper.IndexOf('& chmod -R u+rwX -- $resolvedTemporary')
        $removeIndex = $script:wrapper.IndexOf('Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force')
        ($chmodIndex -ge 0) | Should -BeTrue
        ($removeIndex -gt $chmodIndex) | Should -BeTrue
    }
}
