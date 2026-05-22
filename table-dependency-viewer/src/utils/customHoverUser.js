export const CUSTOM_HOVER_TARGET_USER = "Nikita.Suvorov@rusal.com";
export const CUSTOM_HOVER_LABEL = "душнила";

export function shouldUseCustomHoverLabel(userProfile) {
  if (!CUSTOM_HOVER_TARGET_USER) return false;
  const target = String(CUSTOM_HOVER_TARGET_USER).trim().toLowerCase();
  const targetLogin = target.includes("@") ? target.split("@", 1)[0] : target;
  const username = String(userProfile?.username || "").trim().toLowerCase();
  const email = String(userProfile?.email || "").trim().toLowerCase();

  return (
    username === target ||
    email === target ||
    username === targetLogin ||
    email === targetLogin ||
    username.includes(targetLogin) ||
    email.includes(targetLogin)
  );
}
