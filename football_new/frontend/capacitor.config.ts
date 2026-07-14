import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "pro.edgescore.app",
  appName: "EdgeScore",
  webDir: "dist",
  server: {
    url: "https://edgescore.pro",
    androidScheme: "https",
  },
};

export default config;
