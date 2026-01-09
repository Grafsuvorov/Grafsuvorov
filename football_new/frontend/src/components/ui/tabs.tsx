import * as React from "react";

export function Tabs({ children, value, onChange }) {
  return (
    <div className="w-full">
      {React.Children.map(children, child =>
        React.cloneElement(child, { value, onChange })
      )}
    </div>
  );
}

export function TabsList({ children }) {
  return (
    <div className="flex border-b border-gray-200 mb-2">
      {children}
    </div>
  );
}

export function TabsTrigger({ value, onChange, children }) {
  return (
    <button
      onClick={() => onChange(value)}
      className="px-4 py-2 text-sm font-medium border-b-2 border-transparent hover:border-blue-400 hover:text-blue-600 focus:outline-none"
    >
      {children}
    </button>
  );
}
