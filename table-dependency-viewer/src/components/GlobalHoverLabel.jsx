import React, { useEffect, useState } from "react";
import { CUSTOM_HOVER_LABEL } from "../utils/customHoverUser.js";

const INTERACTIVE_SELECTOR = [
  "button",
  "a[href]",
  "[role='button']",
  "[role='tab']",
  "input[type='checkbox']",
  "input[type='radio']",
  "summary",
  ".click-meta-tab",
  ".meta-mode-tab",
  ".meta-subtab",
  ".branch-catalog-node",
  ".branch-selector-button",
].join(", ");

function isDisabled(target) {
  return Boolean(
    target?.matches?.(":disabled, [aria-disabled='true'], [data-disabled='true']")
  );
}

export default function GlobalHoverLabel({ enabled }) {
  const [state, setState] = useState({
    visible: false,
    x: 0,
    y: 0,
  });

  useEffect(() => {
    document.body.classList.toggle("custom-hover-label-enabled", Boolean(enabled));
    if (!enabled) {
      document.body.classList.remove("custom-hover-label-active");
      setState((current) => ({ ...current, visible: false }));
      return undefined;
    }

    const handleMove = (event) => {
      const interactiveTarget = event.target.closest?.(INTERACTIVE_SELECTOR);
      const visible = Boolean(interactiveTarget && !isDisabled(interactiveTarget));
      document.body.classList.toggle("custom-hover-label-active", visible);
      setState({
        visible,
        x: event.clientX + 18,
        y: event.clientY + 20,
      });
    };

    const hide = () => {
      document.body.classList.remove("custom-hover-label-active");
      setState((current) => ({ ...current, visible: false }));
    };

    document.addEventListener("mousemove", handleMove);
    document.addEventListener("mouseleave", hide);
    window.addEventListener("blur", hide);

    return () => {
      document.body.classList.remove("custom-hover-label-enabled");
      document.body.classList.remove("custom-hover-label-active");
      document.removeEventListener("mousemove", handleMove);
      document.removeEventListener("mouseleave", hide);
      window.removeEventListener("blur", hide);
    };
  }, [enabled]);

  return (
    <div
      className={`global-hover-label ${state.visible ? "is-visible" : ""}`}
      style={{
        transform: `translate3d(${state.x}px, ${state.y}px, 0)`,
      }}
    >
      {CUSTOM_HOVER_LABEL}
    </div>
  );
}
