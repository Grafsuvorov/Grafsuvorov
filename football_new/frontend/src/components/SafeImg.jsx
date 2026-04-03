import React from "react";

const FALLBACK_SVG =
  "data:image/svg+xml;utf8," +
  encodeURIComponent(
    `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
       <rect width='100%' height='100%' fill='#f3f4f6'/>
       <path d='M20 4l12 6v8c0 8-6 14-12 18C14 32 8 26 8 18V10l12-6z' fill='#d1d5db'/>
     </svg>`
  );

export default function SafeImg({ src, alt = "", className = "", fallbackSrc = null }) {
  const handleError = (e) => {
    e.currentTarget.onerror = null;
    e.currentTarget.src = fallbackSrc || FALLBACK_SVG;
  };

  return (
    <img
      src={src}
      alt={alt}
      className={className}
      onError={handleError}
      loading="lazy"
      decoding="async"
      draggable={false}
    />
  );
}
