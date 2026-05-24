##Module Api

class DeepSeekClient {
    [string]$Model
    [string]$ApiKey
    [hashtable]$Headers
    [bool]$Debug

    DeepSeekClient([string]$model, [string]$apiKey, [bool]$debug) {
        $this.Model = $model
        $this.ApiKey = $apiKey
        $this.Debug = $debug
        $this.Headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type"  = "application/json"
        }
    }

    [string] SendMessage([array]$messages, [int]$maxRetries, [int]$timeoutSec) {
        $requestBody = @{
            model           = $this.Model
            messages        = $messages
            response_format = @{ type = "json_object" }
            max_tokens      = 512
        } | ConvertTo-Json -Depth 4 -Compress

        for ($retry = 0; $retry -le $maxRetries; $retry++) {
            try {
                $response = Invoke-RestMethod -Uri "https://api.deepseek.com/chat/completions" `
                                              -Method Post `
                                              -Headers $this.Headers `
                                              -Body $requestBody `
                                              -TimeoutSec $timeoutSec `
                                              -ErrorAction Stop
                return $response.choices[0].message.content
            }
            catch {
                if ($this.Debug) {
                    Write-Warning "API 调用失败 (尝试 $($retry+1)/$($maxRetries+1)): $_"
                }
                if ($retry -lt $maxRetries) {
                    Start-Sleep -Seconds 1
                }
            }
        }
        Write-Error "API 调用最终失败，跳过本次请求"
        return $null
    }

    static [PSCustomObject] ParseJsonResponse([string]$jsonString) {
        try {
            $obj = $jsonString | ConvertFrom-Json -ErrorAction Stop
            if ($null -ne $obj.thought) {
                return $obj
            }
        } catch {}
        return [PSCustomObject]@{ thought = $jsonString; mood_update = "" }
    }
}
