import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Mail, ArrowLeft } from 'lucide-react';
import Input from '../../components/ui/Input';
import Button from '../../components/ui/Button';
import { useAuthStore } from '../../store/auth-store';
import { toast } from 'react-hot-toast';

const ForgotPasswordPage: React.FC = () => {
  const [email, setEmail] = useState('');
  const [emailSent, setEmailSent] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  
  const { resetPassword, isLoading, error, clearError } = useAuthStore();
  
  useEffect(() => {
    // Clear any previous auth errors
    clearError();
  }, [clearError]);
  
  useEffect(() => {
    if (error) {
      toast.error(error);
    }
  }, [error]);
  
  const validateForm = (): boolean => {
    if (!email) {
      setFormError('Email is required');
      return false;
    } else if (!/\S+@\S+\.\S+/.test(email)) {
      setFormError('Email is invalid');
      return false;
    }
    
    setFormError(null);
    return true;
  };
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) return;
    
    try {
      await resetPassword(email);
      setEmailSent(true);
      toast.success('Password reset instructions sent to your email');
    } catch (err) {
      // Error is already handled by the store
    }
  };
  
  if (emailSent) {
    return (
      <div className="max-w-md mx-auto py-12 px-4">
        <div className="bg-white rounded-lg shadow-md p-8 text-center">
          <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-6">
            <Mail className="h-8 w-8 text-green-600" />
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-4">Check your email</h2>
          <p className="text-gray-600 mb-6">
            We've sent password reset instructions to <span className="font-medium">{email}</span>
          </p>
          <div className="space-y-4">
            <Button
              onClick={() => setEmailSent(false)}
              variant="outline"
              className="w-full"
            >
              Try a different email
            </Button>
            <Link 
              to="/login" 
              className="block text-blue-600 hover:text-blue-800"
            >
              Back to login
            </Link>
          </div>
        </div>
      </div>
    );
  }
  
  return (
    <div className="max-w-md mx-auto py-12 px-4">
      <div className="text-center mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Forgot your password?</h1>
        <p className="text-gray-600">No worries, we'll send you reset instructions</p>
      </div>
      
      <div className="bg-white rounded-lg shadow-md p-6 mb-6">
        <form onSubmit={handleSubmit} className="space-y-6">
          <Input
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Enter your email address"
            leftIcon={<Mail className="h-5 w-5" />}
            error={formError || undefined}
            disabled={isLoading}
          />
          
          <Button
            type="submit"
            className="w-full"
            isLoading={isLoading}
          >
            Reset Password
          </Button>
        </form>
      </div>
      
      <div className="text-center">
        <Link 
          to="/login" 
          className="inline-flex items-center text-blue-600 hover:text-blue-800"
        >
          <ArrowLeft className="h-4 w-4 mr-2" />
          Back to login
        </Link>
      </div>
    </div>
  );
};

export default ForgotPasswordPage;