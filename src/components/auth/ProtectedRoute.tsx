import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuthStore } from '../../store/auth-store';
import { User } from '../../types';

interface ProtectedRouteProps {
  children: React.ReactNode;
  requiredRole?: User['role'];
}

const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ 
  children, 
  requiredRole
}) => {
  const { isAuthenticated, user } = useAuthStore();
  
  // If not authenticated, redirect to login
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  
  // If role is required and user doesn't have it, redirect to home
  if (requiredRole && user?.role !== requiredRole) {
    return <Navigate to="/" replace />;
  }
  
  return <>{children}</>;
};

export default ProtectedRoute;