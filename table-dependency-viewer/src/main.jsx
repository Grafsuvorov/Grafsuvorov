import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App.jsx";

import "./index.css";

const AUTH_ENABLED = import.meta.env.VITE_AUTH_ENABLED === "true";
const TOKEN_KEY = "tdv_access_token";
const USER_KEY = "tdv_user_profile";

if (AUTH_ENABLED && typeof window !== "undefined") {
  const originalFetch = window.fetch.bind(window);
  let authRedirectInProgress = false;
  window.fetch = (input, init = {}) => {
    const token = localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY);
    const headers = new Headers(init.headers || {});
    if (token && !headers.has("Authorization")) {
      headers.set("Authorization", `Bearer ${token}`);
    }
    const request = originalFetch(input, { ...init, headers });
    return request.then((response) => {
      const url =
        typeof input === "string"
          ? input
          : input instanceof Request
            ? input.url
            : String(input || "");
      const isLoginRequest = url.includes("/auth/login");
      if (response.status === 401 && !isLoginRequest && !authRedirectInProgress) {
        authRedirectInProgress = true;
        localStorage.removeItem(TOKEN_KEY);
        localStorage.removeItem(USER_KEY);
        sessionStorage.removeItem(TOKEN_KEY);
        sessionStorage.removeItem(USER_KEY);
        if (window.location.pathname !== "/login") {
          const nextPath = `${window.location.pathname}${window.location.search || ""}`;
          const params = new URLSearchParams({
            reason: "session-expired",
            next: nextPath,
          });
          window.location.replace(`/login?${params.toString()}`);
        } else {
          authRedirectInProgress = false;
        }
      }
      return response;
    });
  };
}

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>
);
