// Seeds the automaton's model registry so inference routes to the free
// local Ollama model and never to paid cloud models.
// Must be run from inside the cloned automaton/ directory (needs ./dist).
import { createDatabase, modelRegistryUpsert } from "./dist/state/database.js";
import os from "node:os";
import path from "node:path";

const db = createDatabase(path.join(os.homedir(), ".automaton", "state.db"));
const now = new Date().toISOString();

modelRegistryUpsert(db.raw, {
  modelId: "qwen2.5:0.5b",
  provider: "ollama",
  displayName: "Qwen 2.5 0.5b (local)",
  tierMinimum: "critical",
  costPer1kInput: 0,
  costPer1kOutput: 0,
  maxTokens: 1024,
  contextWindow: 32768,
  supportsTools: true,
  supportsVision: false,
  parameterStyle: "max_tokens",
  enabled: true,
  createdAt: now,
  updatedAt: now,
});

for (const id of ["gpt-5.2", "gpt-5.3", "gpt-5-mini", "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano"]) {
  modelRegistryUpsert(db.raw, {
    modelId: id,
    provider: "conway",
    displayName: id,
    tierMinimum: "critical",
    costPer1kInput: 1000,
    costPer1kOutput: 2000,
    maxTokens: 4096,
    contextWindow: 8192,
    supportsTools: true,
    supportsVision: false,
    parameterStyle: "max_tokens",
    enabled: false,
    createdAt: now,
    updatedAt: now,
  });
}

console.log("registry seeded: qwen2.5:0.5b enabled, cloud models disabled");
db.close();
