export default function EdgeScoreLogoGlass({ size = 34 }) {
  return (
    <div className="flex items-center gap-2 select-none text-white">
      <svg
        width={size}
        height={size}
        viewBox="0 0 34 34"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        className="shrink-0"
      >
        <circle cx="17" cy="17" r="14" fill="url(#bg)" opacity="0.35"/>
        <circle cx="17" cy="17" r="12" stroke="url(#ring)" strokeWidth="2" opacity="0.9"/>
        <circle cx="17" cy="17" r="6" stroke="url(#inner)" strokeWidth="2" opacity="0.9"/>
        <circle cx="17" cy="17" r="3" fill="url(#core)"/>
        <ellipse cx="13" cy="12" rx="4" ry="2" fill="white" opacity="0.15"/>
        <ellipse cx="21" cy="22" rx="3" ry="1.5" fill="white" opacity="0.06"/>

        <defs>
          <radialGradient id="bg" cx="0" cy="0" r="1"
            gradientTransform="translate(17 17) scale(14)">
            <stop stopColor="#FFFFFF" stopOpacity="0.18"/>
            <stop offset="1" stopColor="#FFFFFF" stopOpacity="0"/>
          </radialGradient>

          <linearGradient id="ring" x1="0" y1="0" x2="34" y2="34">
            <stop stopColor="#FFFFFF" stopOpacity="0.9"/>
            <stop offset="1" stopColor="#A6B0C5" stopOpacity="0.45"/>
          </linearGradient>

          <linearGradient id="inner" x1="10" y1="10" x2="26" y2="26">
            <stop stopColor="#FFFFFF"/>
            <stop offset="1" stopColor="#A6B0C5" stopOpacity="0.5"/>
          </linearGradient>

          <radialGradient id="core"
            gradientTransform="translate(17 17) scale(4)">
            <stop stopColor="#FFFFFF"/>
            <stop offset="1" stopColor="#C9D2E3" stopOpacity="0.6"/>
          </radialGradient>
        </defs>
      </svg>

      <span className="text-xl font-semibold tracking-tight">EdgeScore</span>
    </div>
  );
}
