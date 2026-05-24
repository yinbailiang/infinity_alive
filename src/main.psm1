##Module Main
##Import StreamEngine

using module src/api.psm1 #infb: rm
using module src/state.psm1 #infb: rm
using module src/memory.psm1 #infb: rm
using module src/environment.psm1 #infb: rm
using module src/prompt.psm1 #infb: rm
using module src/stream_engine.psm1 #infb: rm

function Invoke-Main {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CharacterName,

        [Parameter(Mandatory = $true)]
        [string]$Personality,

        [string]$Environment = "一间安静的房间里",

        [ValidateSet('deepseek-v4-flash', 'deepseek-v4-pro')]
        [string]$Model = 'deepseek-v4-flash',

        [string]$ApiKey,

        [switch]$Force,

        [ValidateRange(1, 300)]
        [int]$MinInterval = 10,

        [ValidateRange(1, 300)]
        [int]$MaxInterval = 60,

        [string]$LogFile
    )

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # 解析 API 密钥
    if (-not $ApiKey) { $ApiKey = $env:DEEPSEEK_API_KEY }
    if (-not $ApiKey) {
        Write-Error "缺少 DeepSeek API 密钥。请通过 -ApiKey 参数指定，或设置环境变量 DEEPSEEK_API_KEY。"
        exit 1
    }

    # 构建对象图（依赖注入）
    $isDebug = ($BuildMode -eq "Debug")
    $api = [DeepSeekClient]::new($Model, $ApiKey, $isDebug)
    $character = [CharacterState]::new($CharacterName, $Personality)
    $memory = [MemoryManager]::new()
    $env = [EnvironmentManager]::new($api, $Environment)
    $config = [StreamConfig]::new($MinInterval, $MaxInterval, $LogFile, $isDebug)
    $engine = [StreamEngine]::new($character, $memory, $env, $api, $config)

    $engine.Run()
}
