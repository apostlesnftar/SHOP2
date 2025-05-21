import React, { useState, useEffect, useCallback } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { User, Mail, Lock, AlertCircle } from 'lucide-react';
import Input from '../../components/ui/Input';
import Button from '../../components/ui/Button';
import { useAuthStore } from '../../store/auth-store';
import { toast } from 'react-hot-toast';

const RegisterPage = () => {
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [formErrors, setFormErrors] = useState<{
    username?: string;
    email?: string;
    password?: string;
    confirmPassword?: string;
  }>({});
  
  const navigate = useNavigate();
  const { register, isLoading, error, isAuthenticated, clearError } = useAuthStore();
  const location = useLocation();
  
  // Extract referral code from URL if present
  const [referralCode, setReferralCode] = useState<string | null>(null);
  
  const parseReferralCode = useCallback(() => {
    const searchParams = new URLSearchParams(location.search);
    const ref = searchParams.get('ref');
    if (ref) {
      console.log('Referral code detected in URL:', ref);
      setReferralCode(ref);
    }
  }, [location.search]);
  
  useEffect(() => {
    // If already authenticated, redirect to home
    if (isAuthenticated) {
      navigate('/');
    }
    
    // Clear any previous auth errors and parse referral code
    clearError();
    parseReferralCode();
  }, [isAuthenticated, navigate, clearError, parseReferralCode]);
  
  useEffect(() => {
    if (error) {
      toast.error(error);
    }
  }, [error]);
  
  const validateForm = (): boolean => {
    const errors: {
      username?: string;
      email?: string;
      password?: string;
      confirmPassword?: string;
    } = {};
    
    if (!username) {
      errors.username = 'Username is required';
    }
    
    if (!email) {
      errors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(email)) {
      errors.email = 'Email is invalid';
    }
    
    if (!password) {
      errors.password = 'Password is required';
    } else if (password.length < 6) {
      errors.password = 'Password must be at least 6 characters';
    }
    
    if (!confirmPassword) {
      errors.confirmPassword = 'Please confirm your password';
    } else if (password !== confirmPassword) {
      errors.confirmPassword = 'Passwords do not match';
    }
    
    setFormErrors(errors);
    return Object.keys(errors).length === 0;
  };
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) return;
    
    try {
      // Log registration details for debugging
      console.log('Submitting registration with details:', {
        username,
        email,
        referralCode: referralCode || 'none'
      });
      
      await register(username, email, password, referralCode);
      toast.success('Registration successful!');
      
      // If there was a referral code, show additional success message
      if (referralCode) {
        toast.success('You have been added to your referrer\'s team!');
      }
    } catch (err) {
      // Error is already handled by the store
    }
  };
  
  return (
    <div className="max-w-md mx-auto py-12 px-4">
      <div className="text-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Create an account</h1>
        <p className="text-gray-600">Sign up to start shopping or become an agent</p>
        {referralCode && (
          <div className="mt-2 p-2 bg-blue-50 text-blue-700 rounded-md flex items-start">
            <AlertCircle className="h-5 w-5 text-blue-600 mt-0.5 mr-2 flex-shrink-0" />
            <div>
              <p className="font-medium">Agent Referral Detected</p>
              <p className="text-sm">You're being referred by an agent (ID: {referralCode}). You'll be added to their team upon registration.</p>
            </div>
          </div>
        )}
      </div>
      
      <div className="bg-white rounded-lg shadow-md p-6 mb-6">
        <form onSubmit={handleSubmit} className="space-y-4">
          <Input
            label="Username"
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            placeholder="Enter your username"
            leftIcon={<User className="h-5 w-5" />}
            error={formErrors.username}
            disabled={isLoading}
          />
          
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
            placeholder="Create a password"
            leftIcon={<Lock className="h-5 w-5" />}
            error={formErrors.password}
            disabled={isLoading}
          />
          
          <Input
            label="Confirm Password"
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            placeholder="Confirm your password"
            leftIcon={<Lock className="h-5 w-5" />}
            error={formErrors.confirmPassword}
            disabled={isLoading}
          />
          
          <div className="flex items-center">
            <input
              type="checkbox"
              id="terms"
              className="rounded border-gray-300 text-blue-600 shadow-sm focus:border-blue-300 focus:ring focus:ring-blue-200 focus:ring-opacity-50"
              required
            />
            <label htmlFor="terms" className="ml-2 text-sm text-gray-600">
              I agree to the{' '}
              <Link to="/terms" className="text-blue-600 hover:text-blue-800">
                Terms of Service
              </Link>{' '}
              and{' '}
              <Link to="/privacy" className="text-blue-600 hover:text-blue-800">
                Privacy Policy
              </Link>
            </label>
          </div>
          
          <Button
            type="submit"
            className="w-full"
            isLoading={isLoading}
          >
            Create Account
          </Button>
        </form>
      </div>
      
      <div className="text-center">
        <p className="text-gray-600">
          Already have an account?{' '}
          <Link to="/login" className="text-blue-600 hover:text-blue-800 font-medium">
            Sign in
          </Link>
        </p>
      </div>
    </div>
  );
};

export default RegisterPage;