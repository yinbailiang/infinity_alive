##Module Memory

class MemoryManager {
    [System.Collections.Generic.List[string]]$Memorys

    MemoryManager() {
        $this.Memorys = [System.Collections.Generic.List[string]]::new()
    }

    [void] AddMemory([string]$Mem) {
        $this.Memorys.Add($Mem)
    }


    [string] GetSummary() {
        return $this.Memorys -join "`n"
    }
}
