import React from 'react';
import { cn } from '../../lib/utils';
import { getInitials } from '../../lib/utils';

interface AvatarProps extends React.HTMLAttributes<HTMLDivElement> {
  src?: string;
  alt?: string;
  name?: string;
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  status?: 'online' | 'offline' | 'away' | 'busy';
}

const Avatar = React.forwardRef<HTMLDivElement, AvatarProps>(
  ({ className, src, alt, name, size = 'md', status, ...props }, ref) => {
    const [imgError, setImgError] = React.useState(false);
    
    const sizeStyles = {
      xs: 'h-6 w-6 text-xs',
      sm: 'h-8 w-8 text-sm',
      md: 'h-10 w-10 text-base',
      lg: 'h-12 w-12 text-lg',
      xl: 'h-16 w-16 text-xl',
    };
    
    const statusStyles = {
      online: 'bg-green-500',
      offline: 'bg-gray-400',
      away: 'bg-amber-500',
      busy: 'bg-red-500',
    };
    
    const statusSizeStyles = {
      xs: 'h-1.5 w-1.5',
      sm: 'h-2 w-2',
      md: 'h-2.5 w-2.5',
      lg: 'h-3 w-3',
      xl: 'h-3.5 w-3.5',
    };
    
    return (
      <div ref={ref} className={cn('relative inline-block', className)} {...props}>
        <div
          className={cn(
            'flex items-center justify-center rounded-full bg-gray-200 overflow-hidden',
            sizeStyles[size]
          )}
        >
          {src && !imgError ? (
            <img
              src={src}
              alt={alt || name || 'Avatar'}
              className="h-full w-full object-cover"
              onError={() => setImgError(true)}
            />
          ) : name ? (
            <span className="font-medium text-gray-700">{getInitials(name)}</span>
          ) : (
            <span className="font-medium text-gray-700">??</span>
          )}
        </div>
        
        {status && (
          <span
            className={cn(
              'absolute bottom-0 right-0 block rounded-full ring-2 ring-white',
              statusStyles[status],
              statusSizeStyles[size]
            )}
          />
        )}
      </div>
    );
  }
);

Avatar.displayName = 'Avatar';

export default Avatar;