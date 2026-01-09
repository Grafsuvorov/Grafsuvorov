/** EdgeScore Premium Tailwind Preset **/
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: "#8B8DFF",            // главный акцент
        accent: "#8B8DFF",             // синоним для удобства

        // сигнальные зоны
        zone: {
          ucl: "#06B6D4",              // Лига чемпионов
          euro: "#34D399",             // Еврокубки
          releg: "#F43F5E"             // Вылет
        },

        // текстовые цвета
        muted: "#94A3B8",              // slate-400
      },

      // поверхности интерфейса (слои стеклянного UI)
      backgroundColor: {
        "surface-1": "rgba(10,18,35,0.92)",   // крупные панели
        "surface-2": "rgba(7,13,26,0.45)",    // панели таблиц
        "surface-3": "rgba(7,13,26,0.35)",    // строки таблиц
        "glass-soft": "rgba(255,255,255,0.05)",
      },

      borderColor: {
        glass: "rgba(255,255,255,0.05)",      // универсальный border
      },

      boxShadow: {
        "glow-primary": "0 0 25px rgba(139,141,255,0.6)",
        "glow-primary-lg": "0 0 35px rgba(139,141,255,0.75)",
        "hover-soft": "0 0 16px rgba(255,255,255,0.05)",
        "panel": "0 18px 60px rgba(0,0,0,0.65)",
      },

      backdropBlur: {
        glass: "16px",
      },

      // радиусы, чтобы всё было едино
      borderRadius: {
        xl2: "1.25rem",
        xl3: "1.75rem",
      }
    }
  },

  plugins: [
    // удобные кастомные классы
    function ({ addComponents, theme }) {
      addComponents({
        // основной CTA
        ".btn-primary": {
          backgroundColor: theme("colors.primary"),
          color: "#0F172A",
          borderRadius: theme("borderRadius.xl"),
          padding: "0.5rem 1.2rem",
          fontWeight: "600",
          boxShadow: theme("boxShadow.glow-primary"),
          transition: "all .2s",
        },
        ".btn-primary:hover": {
          boxShadow: theme("boxShadow.glow-primary-lg"),
        },

        // стеклянная кнопка
        ".btn-glass": {
          backgroundColor: "rgba(255,255,255,0.05)",
          border: "1px solid rgba(255,255,255,0.08)",
          borderRadius: theme("borderRadius.xl"),
          padding: "0.45rem 1rem",
          fontWeight: "500",
          color: "#E2E8F0",
          transition: "all .2s",
        },
        ".btn-glass:hover": {
          backgroundColor: "rgba(255,255,255,0.1)",
        },

        // табы
        ".tab-default": {
          border: "1px solid rgba(255,255,255,0.1)",
          backgroundColor: "transparent",
          borderRadius: "9999px",
          padding: "0.35rem 1rem",
          color: "#CBD5E1",
          fontWeight: "600",
          transition: "all .2s",
        },
        ".tab-default:hover": {
          backgroundColor: "rgba(255,255,255,0.05)",
        },

        ".tab-active": {
          backgroundColor: theme("colors.primary"),
          color: "#0F172A",
          border: `1px solid ${theme("colors.primary")}`,
          borderRadius: "9999px",
          padding: "0.35rem 1rem",
          fontWeight: "700",
          boxShadow: theme("boxShadow.glow-primary"),
          transition: "all .2s",
        },

        // hover для строк
        ".hover-glow": {
          transition: "all .15s",
        },
        ".hover-glow:hover": {
          backgroundColor: "rgba(255,255,255,0.08)",
          boxShadow: theme("boxShadow.hover-soft"),
        },

        // стандартные панели
        ".panel": {
          backgroundColor: theme("backgroundColor.surface-1"),
          borderRadius: theme("borderRadius.xl3"),
          border: `1px solid ${theme("borderColor.glass")}`,
          backdropFilter: "blur(16px)",
          boxShadow: theme("boxShadow.panel"),
        },

        // таблица
        ".table-surface": {
          backgroundColor: theme("backgroundColor.surface-2"),
          borderRadius: theme("borderRadius.xl3"),
          border: `1px solid ${theme("borderColor.glass")}`,
          overflow: "hidden",
          backdropFilter: "blur(16px)",
        },
      });
    },
  ],
};
