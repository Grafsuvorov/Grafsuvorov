import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App.jsx";

import "./index.css";

const AUTH_ENABLED = import.meta.env.VITE_AUTH_ENABLED === "true";
const TOKEN_KEY = "tdv_access_token";

if (AUTH_ENABLED && typeof window !== "undefined") {
  const originalFetch = window.fetch.bind(window);
  window.fetch = (input, init = {}) => {
    const token = localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY);
    if (token) {
      const headers = new Headers(init.headers || {});
      if (!headers.has("Authorization")) {
        headers.set("Authorization", `Bearer ${token}`);
      }
      return originalFetch(input, { ...init, headers });
    }
    return originalFetch(input, init);
  };
}

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>
);
