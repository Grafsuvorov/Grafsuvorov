import * as React from "react";

export function Table({
  children,
  className,
  ...props
}: React.TableHTMLAttributes<HTMLTableElement>) {
  return (
    <table className={["w-full border-collapse text-sm", className].filter(Boolean).join(" ")} {...props}>
      {children}
    </table>
  );
}

export function TableHeader({
  children,
  className,
  ...props
}: React.HTMLAttributes<HTMLTableSectionElement>) {
  return (
    <thead className={["bg-surface-2/80 text-slate-300", className].filter(Boolean).join(" ")} {...props}>
      {children}
    </thead>
  );
}

export function TableRow({
  children,
  className,
  ...props
}: React.HTMLAttributes<HTMLTableRowElement>) {
  return (
    <tr className={["border-b border-glass", className].filter(Boolean).join(" ")} {...props}>
      {children}
    </tr>
  );
}

export function TableHead({
  children,
  className,
  ...props
}: React.ThHTMLAttributes<HTMLTableCellElement>) {
  return (
    <th className={["px-3 py-2 text-left font-semibold text-slate-200", className].filter(Boolean).join(" ")} {...props}>
      {children}
    </th>
  );
}

export function TableBody({
  children,
  className,
  ...props
}: React.HTMLAttributes<HTMLTableSectionElement>) {
  return (
    <tbody className={className} {...props}>
      {children}
    </tbody>
  );
}

export function TableCell({
  children,
  className,
  ...props
}: React.TdHTMLAttributes<HTMLTableCellElement>) {
  return (
    <td className={["px-3 py-2", className].filter(Boolean).join(" ")} {...props}>
      {children}
    </td>
  );
}
