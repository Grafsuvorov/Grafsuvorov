import { createContext, useContext, useState } from "react";

const ThemeContext = createContext();

export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState("pink"); // "pink" | "premium"

  const toggleTheme = () => {
    setTheme((t) => (t === "pink" ? "premium" : "pink"));
  };

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      <div data-theme={theme} className="min-h-screen">
        {children}
      </div>
    </ThemeContext.Provider>
  );
}

export const useTheme = () => useContext(ThemeContext);
