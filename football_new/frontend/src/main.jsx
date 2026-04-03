import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import './index.css';

import { ThemeProvider } from "@/context/ThemeContext";

// TEMP: block deprecated /api/match-events calls to prevent 404 spam
if (typeof window !== "undefined" && !window.__matchEventsBlocked) {
  const originalFetch = window.fetch.bind(window);
  window.fetch = (input, init) => {
    const url = typeof input === "string" ? input : input?.url || "";
    if (url.includes("/api/match-events")) {
      return Promise.resolve(
        new Response("[]", {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      );
    }
    return originalFetch(input, init);
  };
  window.__matchEventsBlocked = true;
}

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <ThemeProvider>
      <App />
    </ThemeProvider>
  </React.StrictMode>
);
