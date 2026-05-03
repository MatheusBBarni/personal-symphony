import "./styles.css";
import React from "react";
import { createRoot } from "react-dom/client";
import { make as Dashboard } from "./Dashboard.res.js";

const root = document.getElementById("root");
const app = root ? createRoot(root) : null;

function valueAt(object, path, fallback = "") {
  return path.reduce((current, key) => {
    if (current && Object.prototype.hasOwnProperty.call(current, key)) {
      return current[key];
    }
    return undefined;
  }, object) ?? fallback;
}

async function loadState() {
  if (!app) return;
  app.render(React.createElement(Dashboard, { snapshot: undefined, error: undefined }));

  try {
    const response = await fetch("/api/v1/state", { headers: { Accept: "application/json" } });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const state = await response.json();
    app.render(
      React.createElement(Dashboard, {
        snapshot: {
          running: String(valueAt(state, ["counts", "running"], 0)),
          retrying: String(valueAt(state, ["counts", "retrying"], 0)),
          tokens: String(valueAt(state, ["codex_totals", "total_tokens"], 0)),
          generatedAt: String(valueAt(state, ["generated_at"], "")),
          lastError: String(valueAt(state, ["last_error"], ""))
        },
        error: undefined
      })
    );
  } catch (error) {
    app.render(
      React.createElement(Dashboard, {
        snapshot: undefined,
        error: error instanceof Error ? error.message : "Unable to load state"
      })
    );
  }
}

loadState();
setInterval(loadState, 5000);
