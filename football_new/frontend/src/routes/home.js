// src/routes/home.js
export const HOME_QS = new URLSearchParams({
  league: "Premier League",
  season: "2025",
  view: "total",
}).toString();

export const HOME_URL = `/table?${HOME_QS}`;
