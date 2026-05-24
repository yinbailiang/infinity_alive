##Module StreamEngine
##Import Api
##Import State
##Import Memory
##Import Environment
##Import Prompt

using module src/api.psm1 #infb: rm
using module src/state.psm1 #infb: rm
using module src/memory.psm1 #infb: rm
using module src/environment.psm1 #infb: rm
using module src/prompt.psm1 #infb: rm

class StreamConfig {
    [int]$MinInterval
    [int]$MaxInterval
    [string]$LogFile
    [bool]$Debug

    StreamConfig([int]$minInterval, [int]$maxInterval, [string]$logFile, [bool]$debug) {
        $this.MinInterval = $minInterval
        $this.MaxInterval = $maxInterval
        $this.LogFile = $logFile
        $this.Debug = $debug
    }
}

class StreamEngine {
    [CharacterState]$Character
    [MemoryManager]$Memory
    [EnvironmentManager]$Environment
    [DeepSeekClient]$Api
    [StreamConfig]$Config

    StreamEngine(
        [CharacterState]$character,
        [MemoryManager]$memory,
        [EnvironmentManager]$environment,
        [DeepSeekClient]$api,
        [StreamConfig]$config
    ) {
        $this.Character = $character
        $this.Memory = $memory
        $this.Environment = $environment
        $this.Api = $api
        $this.Config = $config
    }

    [string] BuildSystemPrompt() {
        return [PromptBuilder]::BuildSystemPrompt(
            $this.Character,
            $this.Environment.Description,
            $this.Memory.GetSummary()
        )
    }

    [PSCustomObject] GenerateThought() {
        $sys = $this.BuildSystemPrompt()
        $messages = @(
            @{ role = "system"; content = $sys }
            @{ role = "user"; content = "继续你的思绪。" }
        )
        $raw = $this.Api.SendMessage($messages, 2, 60)
        if (-not $raw) { return $null }

        $parsed = [DeepSeekClient]::ParseJsonResponse($raw)

        $this.Character.UpdateLastThought($parsed.thought)
        $this.Character.UpdateMood($parsed.mood_update)
        $this.Memory.AddMemory($parsed.thought)

        $this.WriteLog("[思考] $($parsed.thought)")
        return $parsed
    }

    [void] ProcessUserInput([string]$userText) {
        if ($userText -eq "/exit") {
            Write-Host "`n[系统] 收到退出指令，正在退出..." -ForegroundColor Yellow
            $this.WriteLog("===== 会话结束 =====")
            exit 0
        }
        if ($userText -eq "/save") {
            if (-not $this.Config.LogFile) {
                Write-Host "[系统] 未指定 LogFile 参数，无法保存。" -ForegroundColor Yellow
            }
            else {
                Write-Host "[系统] 当前日志已实时保存到: $($this.Config.LogFile)" -ForegroundColor Green
            }
            return
        }
        if ($userText -eq "/detail") {
            Write-Host "`n[系统] 展示细节" -ForegroundColor Green
            Write-Host ($this.BuildSystemPrompt()) -ForegroundColor Green
            return
        }

        $sys = $this.BuildSystemPrompt()
        $messages = @(
            @{ role = "system"; content = $sys }
            @{ role = "user"; content = "就在这时，用户对你说：$userText。请先回应他（使用 [SPEAK: ...]），然后再回到你的内心世界。同时，请考虑你的情绪是否受到影响，在 mood_update 中体现。" }
        )
        $raw = $this.Api.SendMessage($messages, 2, 60)
        if (-not $raw) {
            Write-Host "[系统] 生成回应失败，角色沉默不语。" -ForegroundColor DarkYellow
            return
        }
        $parsed = [DeepSeekClient]::ParseJsonResponse($raw)

        $thought = $parsed.thought
        $this.Character.UpdateLastThought($thought)
        $this.Character.UpdateMood($parsed.mood_update)
        $this.Memory.AddMemory($thought)

        $speech = ""
        if ($thought -match '\[SPEAK:\s*([^\]]+)\]') {
            $speech = $Matches[1]
            Write-Host "[$($this.Character.Name) 说]: " -NoNewline -ForegroundColor Green
            Write-Host $speech -ForegroundColor White
        }

        if ($thought -match '\[ACT:\s*([^\]]+)\]') {
            $act = $Matches[1]
            Write-Host "* $($this.Character.Name) $act *" -ForegroundColor Magenta
            $this.Environment.UpdateFromAction($act)
        }

        if (-not $speech) {
            Write-Host "[$($this.Character.Name) 没有直接说话，只是内心活动]" -ForegroundColor Gray
        }
        Write-Host "[$($this.Character.Name) 的内心] $thought" -ForegroundColor DarkGray

        $this.WriteLog("[对话] 用户: $userText | 角色: $speech")
    }

    [double] GetInterval() {
        $interval = Get-Random -Minimum $this.Config.MinInterval -Maximum ($this.Config.MaxInterval + 1)
        if ($this.Character.Mood -match '兴奋|不安|焦虑') {
            $interval = [math]::Max(5, $interval / 3)
        }
        if ($this.Character.Mood -match '疲惫|困倦|麻木') {
            $interval = [math]::Min(120, $interval * 1.5)
        }
        return $interval
    }

    [void] DisplayThought([PSCustomObject]$parsed) {
        if (-not $parsed) { return }
        $thought = $parsed.thought
        Write-Host "[$($this.Character.Name) 的内心] $thought" -ForegroundColor DarkGray
        if ($thought -match '\[SPEAK:\s*([^\]]+)\]') {
            Write-Host "[$($this.Character.Name) 说]: $($Matches[1])" -ForegroundColor Green
        }
        if ($thought -match '\[ACT:\s*([^\]]+)\]') {
            $act = $Matches[1]
            Write-Host "* $($this.Character.Name) $act *" -ForegroundColor Magenta
            $this.Environment.UpdateFromAction($act)
        }
    }

    [void] Run() {
        Write-Host "`n===== 流系统启动：$($this.Character.Name) =====" -ForegroundColor Yellow
        Write-Host "按回车输入话语（直接回车则什么也不说），输入 /exit 退出，/save 查看保存状态， /detail 展示细节。" -ForegroundColor Gray
        Write-Host "按 Ctrl+C 也可以停止。`n"

        $this.WriteLog("===== 会话开始：$($this.Character.Name) =====")

        # 初始思考
        $initialThought = $this.GenerateThought()
        $this.DisplayThought($initialThought)

        while ($true) {
            $interval = $this.GetInterval()
            Write-Host "`n（等待 $([math]::Round($interval, 1)) 秒，按回车可打断）" -ForegroundColor DarkGray

            $remaining = $interval
            $userInput = $null
            $timer = [System.Diagnostics.Stopwatch]::StartNew()
            while ($remaining -gt 0) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq [ConsoleKey]::Enter) {
                        Write-Host "`n[你] " -NoNewline -ForegroundColor Cyan
                        $userInput = [Console]::ReadLine()
                        break
                    }
                }
                Start-Sleep -Milliseconds 200
                $remaining = $interval - $timer.Elapsed.TotalSeconds
            }
            $timer.Stop()

            if ($null -ne $userInput -and $userInput.Trim() -ne "") {
                $this.ProcessUserInput($userInput)
            }
            else {
                $thought = $this.GenerateThought()
                $this.DisplayThought($thought)
            }
        }
    }

    hidden [void] WriteLog([string]$text) {
        if ($this.Config.LogFile) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            "$timestamp | $text" | Out-File -FilePath $this.Config.LogFile -Append -Encoding utf8
        }
    }
}
