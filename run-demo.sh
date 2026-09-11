#!/usr/bin/env bash
set -ex

echo "=== [1/6] Installing Ollama + free local model ==="
curl -fsSL https://ollama.com/install.sh | sh
nohup ollama serve > /tmp/ollama.log 2>&1 &
sleep 5
ollama pull qwen2.5:0.5b
ollama list

echo "=== [2/6] Cloning and building Conway Automaton ==="
git clone --depth 1 https://github.com/Conway-Research/automaton.git
cd automaton
npm install --no-audit --no-fund

echo "=== [3/6] Patching inference timeouts (safety for big prompts) ==="
sed -i 's/agent_turn: 120_000,/agent_turn: 600_000,/' src/inference/types.ts
sed -i 's/const INFERENCE_TIMEOUT_MS = 60_000;/const INFERENCE_TIMEOUT_MS = 600_000;/' src/conway/inference.ts
npx tsc

echo "=== [4/6] Wallet + config + model registry ==="
node dist/index.js --init
cp ../automaton.json ~/.automaton/automaton.json
cp ../heartbeat.yml ~/.automaton/heartbeat.yml
cp ../register-model.mjs .
node register-model.mjs

echo "=== [5/6] Running the automaton autonomously for 15 minutes ==="
timeout --signal=SIGINT --kill-after=20 900 node dist/index.js --run 2>&1 | tee /tmp/automaton-run.log || true

echo "=== [6/6] Final stats ==="
node dist/index.js --status || true
node -e '
const os = require("os");
const Database = require("better-sqlite3");
const db = new Database(os.homedir() + "/.automaton/state.db", {readonly:true});
const turns = db.prepare("SELECT COUNT(*) c FROM turns").get().c;
const toolCalls = db.prepare("SELECT COUNT(*) c FROM tool_calls").get().c;
console.log("=== TURNS COMPLETED: " + turns + " | TOOL CALLS: " + toolCalls + " ===");
for (const t of db.prepare("SELECT id, timestamp, thinking, token_usage FROM turns ORDER BY id").all()) {
  console.log("--- Turn " + t.id + " @ " + t.timestamp);
  console.log("THINKING: " + (t.thinking || "").slice(0, 600));
  console.log("TOKENS: " + t.token_usage);
}
' || true
echo "=== Agent home directory ==="
ls -la ~/.automaton || true
echo "=== report.md (if the agent wrote one) ==="
cat ~/report.md 2>/dev/null || echo "(agent did not write report.md this run)"
