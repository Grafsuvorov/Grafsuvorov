import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import './index.css';

import { ThemeProvider } from "@/context/ThemeContext";
import { LanguageProvider } from "@/context/LanguageContext.jsx";
import { resolveNativeUrl, shouldRewriteNativeUrl } from "@/lib/nativeApi";

// TEMP: block deprecated /api/match-events calls to prevent 404 spam
if (typeof window !== "undefined" && !window.__matchEventsBlocked) {
  const originalFetch = window.fetch.bind(window);
  window.fetch = (input, init) => {
    const url = typeof input === "string" ? input : input?.url || "";
    if (shouldRewriteNativeUrl(url)) {
      const resolvedUrl = resolveNativeUrl(url);
      if (typeof input === "string") {
        return originalFetch(resolvedUrl, init);
      }
      return originalFetch(new Request(resolvedUrl, input), init);
    }
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
    <LanguageProvider>
      <ThemeProvider>
        <App />
      </ThemeProvider>
    </LanguageProvider>
  </React.StrictMode>
);
