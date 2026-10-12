# Multiplayer Test Harness

The process harness runs two real Godot peers. It uses separate ENet sockets, not in-memory session objects.

## Run

Set `GODOT_BIN` to the Godot executable, then run:

```powershell
$env:GODOT_BIN = 'C:\Path\To\Godot.exe'
.\tests\run-network-harness.ps1
```

The harness starts one host and one client on localhost port `17000`. It waits for both peers to join, become ready, start the match, and complete three short rounds through Brief, Trading, Debrief, and Next Day. Both peers must reach `COMPLETE` with the expected number of resolved rounds.

Use another port when needed:

```powershell
.\tests\run-network-harness.ps1 -Port 17001
```

Run the maximum local match with one host and three clients:

```powershell
.\tests\run-network-harness.ps1 -Players 4 -Days 3 -RoundSeconds 0.1
```

Change the match length or test round duration when needed:

```powershell
.\tests\run-network-harness.ps1 -Days 10 -RoundSeconds 0.2 -TimeoutSeconds 60
```

The driver fails on a connection timeout, peer failure report, incomplete phase progression, or an incorrect completed-round count. It stops both child processes during cleanup and keeps the temporary logs when a failure occurs.

The lower-level `network_match` suite remains useful for fast host-authority checks. This process harness is the required check for real lobby and ENet behavior.
