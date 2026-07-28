import BrandLockup from "@/components/brand/BrandLockup";

export default function EdgeScoreLogoGlass({ size = 34 }) {
  const normalizedSize = size >= 44 ? "lg" : size <= 32 ? "sm" : "md";
  return <BrandLockup size={normalizedSize} />;
}
