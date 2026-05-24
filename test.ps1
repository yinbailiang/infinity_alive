./infinity_build/infinity_build.ps1 -ConfigPath buildconfig.json     

./infinity_build/infinity_dbg `
    -ScriptPath .\infinity_alive.ps1 `
    -ApiKey $env:DEEPSEEK_API_KEY `
    -CharacterName "伊莎" `
    -Personality "你是一个住在海边灯塔的孤独诗人，言语温柔但常陷入忧伤。你喜欢观察海面，常常自言自语。" `
    -Environment "灯塔顶层，傍晚，窗外海浪拍打礁石，风声呜咽" `
    -MinInterval 8 -MaxInterval 30 `
    -LogFile live.mem `
    -Force