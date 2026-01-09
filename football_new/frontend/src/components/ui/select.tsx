// components/ui/select.tsx
import * as React from "react";
import { ChevronDown } from "lucide-react";

interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  value?: string;
  onValueChange?: (val: string) => void;
}

export const Select = React.forwardRef<HTMLSelectElement, SelectProps>(
  ({ className = "", label, children, value, onValueChange, ...props }, ref) => {
    return (
      <div className="relative">
        {label && (
          <label className="mb-1 block text-sm font-medium text-gray-700">
            {label}
          </label>
        )}
        <select
          ref={ref}
          value={value}
          onChange={(e) => onValueChange?.(e.target.value)} // 👈 именно эта строка делает переключение
          className={
            "block w-full appearance-none rounded-md border border-gray-300 bg-white px-3 py-2 pr-8 text-sm shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 " +
            className
          }
          {...props}
        >
          {children}
        </select>
        <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-700">
          <ChevronDown className="h-4 w-4" />
        </div>
      </div>
    );
  }
);

Select.displayName = "Select";

// 👇 добавь это, если используешь подкомпоненты (можно пустыми, если не нужны)
export const SelectTrigger = ({ children, ...props }) => <>{children}</>;
export const SelectValue = ({ children, ...props }) => <>{children}</>;
export const SelectContent = ({ children, ...props }) => <>{children}</>;
export const SelectItem = ({ children, value, ...props }) => (
  <option value={value} {...props}>
    {children}
  </option>
);
