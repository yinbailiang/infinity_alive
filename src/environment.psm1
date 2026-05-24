##Module Environment
##Import Api

# 修复智能提示
using module src/api.psm1 #infb: rm
class EnvironmentManager {
    [string]$Description
    [DeepSeekClient]$Api

    EnvironmentManager([DeepSeekClient]$api, [string]$initialDescription) {
        $this.Api = $api
        $this.Description = $initialDescription
    }

    [void] UpdateFromAction([string]$actionDescription) {
        $prompt = @"
当前环境：$($this.Description)
角色刚刚做了以下动作：$actionDescription
请根据动作和当前环境，给出新环境描述。
仅输出 JSON：{ "environment": "新描述" }
"@
        $msgs = @(
            @{ role = "system"; content = "你是一个环境描述助手，严格按 JSON 输出。" }
            @{ role = "user"; content = $prompt }
        )
        $raw = $this.Api.SendMessage($msgs, 2, 20)
        if ($raw) {
            $parsed = [DeepSeekClient]::ParseJsonResponse($raw)
            if ($parsed.environment) {
                $this.Description = $parsed.environment
            }
        }
    }
}