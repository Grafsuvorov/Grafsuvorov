import * as React from "react";

export function Table({ children }: { children: React.ReactNode }) {
  return (
    <table className="w-full border-collapse text-sm">{children}</table>
  );
}

export function TableHeader({
  children,
}: { children: React.ReactNode }) {
  return <thead className="bg-surface-2/80 text-slate-300">{children}</thead>;
}

export function TableRow({
  children,
}: { children: React.ReactNode }) {
  return <tr className="border-b border-glass">{children}</tr>;
}

export function TableHead({
  children,
}: { children: React.ReactNode }) {
  return <th className="px-3 py-2 text-left font-semibold text-slate-200">{children}</th>;
}

export function TableBody({
  children,
}: { children: React.ReactNode }) {
  return <tbody>{children}</tbody>;
}

export function TableCell({
  children,
}: { children: React.ReactNode }) {
  return <td className="px-3 py-2">{children}</td>;
}
