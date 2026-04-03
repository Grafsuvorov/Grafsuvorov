module.exports = {
  // ?  EdgeScore Premium preset
  presets: [require("./tailwind.edgescore.preset.js")],

  // ? ,  Tailwind   
  content: [
    "./index.html",
    "./src/**/*.{js,jsx,ts,tsx}",
    "./src/components/**/*.{js,jsx,ts,tsx}",
  ],

  // ? Safelist     
  safelist: [
    { pattern: /bg-(blue|orange|yellow|amber|green|lime)-(400|500|700)/ },
    { pattern: /text-(green|red|gray)-(400|600|700)/ },
  ],

  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter", "ui-sans-serif", "system-ui"],
      },
      // ?  ( )
      animation: {
        "fade-in": "fadeIn 0.3s ease-in-out",
      },
      keyframes: {
        fadeIn: {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
      },
    },
  },

  plugins: [],
};
