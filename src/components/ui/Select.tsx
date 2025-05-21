import React, { SelectHTMLAttributes } from 'react';
import { cn } from '../../lib/utils';

interface SelectOption {
  value: string;
  label: string;
  disabled?: boolean;
}

interface SelectProps extends Omit<SelectHTMLAttributes<HTMLSelectElement>, 'size'> {
  label?: string;
  options: SelectOption[];
  error?: string;
  size?: 'sm' | 'md' | 'lg';
}

const Select = React.forwardRef<HTMLSelectElement, SelectProps>(
  ({ className, label, options, error, size = 'md', id, ...props }, ref) => {
    const inputId = id || label?.toLowerCase().replace(/\s+/g, '-');
    
    const sizeStyles = {
      sm: 'h-8 text-xs px-2',
      md: 'h-10 text-sm px-3',
      lg: 'h-12 text-base px-4',
    };
    
    return (
      <div className="w-full">
        {label && (
          <label 
            htmlFor={inputId}
            className="block text-sm font-medium text-gray-700 mb-1"
          >
            {label}
          </label>
        )}
        <select
          id={inputId}
          ref={ref}
          className={cn(
            'block w-full rounded-md border border-gray-300 bg-white py-2 text-gray-900 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 disabled:opacity-50 appearance-none bg-no-repeat',
            // Background SVG for the dropdown arrow
            "bg-[url('data:image/svg+xml;charset=utf-8,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 fill=%22none%22 viewBox=%220 0 20 20%22%3E%3Cpath stroke=%22%236b7280%22 stroke-linecap=%22round%22 stroke-linejoin=%22round%22 stroke-width=%221.5%22 d=%22m6 8 4 4 4-4%22/%3E%3C/svg%3E')] bg-[position:right_0.5rem_center] bg-[size:1.5em_1.5em]",
            error && 'border-red-500 focus:border-red-500 focus:ring-red-500',
            sizeStyles[size],
            className
          )}
          {...props}
        >
          {options.map((option) => (
            <option 
              key={option.value} 
              value={option.value} 
              disabled={option.disabled}
            >
              {option.label}
            </option>
          ))}
        </select>
        {error && (
          <p className="mt-1 text-sm text-red-600">{error}</p>
        )}
      </div>
    );
  }
);

Select.displayName = 'Select';

export default Select;