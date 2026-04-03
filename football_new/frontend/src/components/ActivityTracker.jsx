import { useEffect, useRef } from "react";
import { useLocation } from "react-router-dom";

import { useAuth } from "@/auth/AuthContext.jsx";
import { authFetch } from "@/lib/authFetch";


export default function ActivityTracker() {
  const { isAuthenticated } = useAuth();
  const location = useLocation();
  const lastKeyRef = useRef("");

  useEffect(() => {
    if (!isAuthenticated) return;

    const path = `${location.pathname}${location.search || ""}`;
    if (!path || lastKeyRef.current === path) return;
    lastKeyRef.current = path;

    const controller = new AbortController();
    authFetch("/api/audit/page-view", {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        path,
        title: typeof document !== "undefined" ? document.title : "",
        referrer: typeof document !== "undefined" ? document.referrer : "",
        user_agent: typeof navigator !== "undefined" ? navigator.userAgent : "",
        source: "spa",
      }),
    }).catch(() => {});

    return () => controller.abort();
  }, [isAuthenticated, location.pathname, location.search]);

  return null;
}
