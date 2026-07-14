// src/routes/home.js
export const HOME_QS = new URLSearchParams({
  league: "Premier League",
  season: "2025",
}).toString();

export const HOME_URL = `/dashboard?${HOME_QS}`;
