export const CUSTOM_HOVER_TARGET_USER = "Nikita.Suvorov@rusal.com";
export const CUSTOM_HOVER_LABEL = "душнила";

export function shouldUseCustomHoverLabel(userProfile) {
  if (!CUSTOM_HOVER_TARGET_USER) return false;
  const username = String(userProfile?.username || "").trim();
  const email = String(userProfile?.email || "").trim();
  return username === CUSTOM_HOVER_TARGET_USER || email === CUSTOM_HOVER_TARGET_USER;
}
