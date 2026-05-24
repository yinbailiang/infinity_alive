##Module State

class CharacterState {
    [string]$Name
    [string]$Personality
    [string]$Mood
    [string]$BodyState
    [string]$LastThought

    CharacterState([string]$name, [string]$personality) {
        $this.Name = $name
        $this.Personality = $personality
        $this.Mood = "平静"
        $this.BodyState = "清醒"
        $this.LastThought = "（意识的起点）"
    }

    [void] UpdateMood([string]$newMood) {
        if (-not [string]::IsNullOrWhiteSpace($newMood)) {
            $this.Mood = $newMood
        }
    }

    [void] UpdateLastThought([string]$thought) {
        if (-not [string]::IsNullOrWhiteSpace($thought)) {
            $this.LastThought = $thought
        }
    }
}
