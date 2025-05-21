import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Mail, Lock, AlertCircle } from 'lucide-react';
import Input from '../../components/ui/Input';
import Button from '../../components/ui/Button';
import { useAuthStore } from '../../store/auth-store';
import { toast } from 'react-hot-toast';

const LoginPage: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [formErrors, setFormErrors] = useState<{ email?: string; password?: string }>({});
  
  const navigate = useNavigate();
  const { login, isLoading, error, isAuthenticated, clearError } = useAuthStore();
  
  useEffect(() => {
    // If already authenticated, redirect to home
    if (isAuthenticated) {
      navigate('/');
    }
    
    // Clear any previous auth errors
    clearError();
  }, [isAuthenticated, navigate, clearError]);
  
  useEffect(() => {
    if (error) {
      toast.error(error);
    }
  }, [error]);
  
  const validateForm = (): boolean => {
    const errors: { email?: string; password?: string } = {};
    
    if (!email) {
      errors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(email)) {
      errors.email = 'Email is invalid';
    }
    
    if (!password) {
      errors.password = 'Password is required';
    }
    
    setFormErrors(errors);
    return Object.keys(errors).length === 0;
  };
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) return;
    
    try {
      await login(email, password);
      toast.success('Login successful!');
    } catch (err) {
      // Error is already handled by the store
    }
  };
  
  // Demo accounts for easy testing
  const demoAccounts = [
    { label: 'Customer', email: 'user@example.com', password: 'password' },
    { label: 'Agent', email: 'agent@example.com', password: 'password' },
    { label: 'Admin', email: 'admin@example.com', password: 'password' },
  ];
  
  const loginWithDemo = async (demoEmail: string, demoPassword: string) => {
    setEmail(demoEmail);
    setPassword(demoPassword);
    try {
      await login(demoEmail, demoPassword);
      toast.success('Login successful!');
    } catch (err) {
      // Error is already handled by the store
    }
  };
  
  return (
    <div className="max-w-md mx-auto py-12 px-4">
      <div className="text-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Welcome back</h1>
        <p className="text-gray-600">Sign in to your account to continue</p>
      </div>
      
      <div className="bg-white rounded-lg shadow-md p-6 mb-6">
        <form onSubmit={handleSubmit} className="space-y-4">
          <Input
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Enter your email"
            leftIcon={<Mail className="h-5 w-5" />}
            error={formErrors.email}
            disabled={isLoading}
          />
          
          <Input
            label="Password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Enter your password"
            leftIcon={<Lock className="h-5 w-5" />}
            error={formErrors.password}
            disabled={isLoading}
          />
          
          <div className="flex justify-between items-center">
            <label className="flex items-center">
              <input
                type="checkbox"
                className="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50"
              />
              <span className="ml-2 text-sm text-gray-600">Remember me</span>
            </label>
            <Link
              to="/forgot-password"
              className="text-sm text-blue-600 hover:text-blue-800"
            >
              Forgot password?
            </Link>
          </div>
          
          <Button
            type="submit"
            className="w-full"
            isLoading={isLoading}
          >
            Sign in
          </Button>
        </form>
      </div>
      
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="mb-4">
          <h2 className="text-lg font-medium text-gray-900">Demo Accounts</h2>
          <p className="text-sm text-gray-500">For testing purposes only</p>
        </div>
        
        <div className="space-y-3">
          {demoAccounts.map((account) => (
            <button
              key={account.email}
              onClick={() => loginWithDemo(account.email, account.password)}
              className="w-full flex items-center justify-between p-3 border border-gray-200 rounded-md hover:bg-gray-50 transition-colors"
              disabled={isLoading}
            >
              <div>
                <span className="font-medium text-gray-900">{account.label}</span>
                <p className="text-sm text-gray-500">{account.email}</p>
              </div>
              <span className="text-blue-600">Use</span>
            </button>
          ))}
        </div>
      </div>
      
      <div className="text-center mt-6">
        <p className="text-gray-600">
          Don't have an account?{' '}
          <Link to="/register" className="text-blue-600 hover:text-blue-800 font-medium">
            Sign up
          </Link>
        </p>
      </div>
    </div>
  );
};

export default LoginPage;