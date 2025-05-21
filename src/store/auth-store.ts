import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { supabase, getCurrentUser } from '../lib/supabase';
import { User } from '../types';

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  login: (email: string, password: string) => Promise<void>; 
  register: (username: string, email: string, password: string, referralCode?: string | null) => Promise<void>;
  logout: () => void;
  resetPassword: (email: string) => Promise<void>;
  clearError: () => void;
  refreshUser: () => Promise<void>;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      token: null,
      isAuthenticated: false,
      isLoading: false,
      error: null,
      
      login: async (email, password) => {
        set({ isLoading: true, error: null });
        try {
          const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password,
          });
          
          if (error) throw error;
          
          // Get user profile data
          const user = await getCurrentUser();
          
          if (!user) {
            throw new Error('Failed to get user information');
          }
          
          set({ 
            user,
            token: data.session?.access_token || null,
            isAuthenticated: true, 
            isLoading: false,
            error: null 
          });
        } catch (error) {
          set({ 
            error: error instanceof Error ? error.message : 'Login failed', 
            isLoading: false,
            isAuthenticated: false
          });
          throw error;
        }
      },
      
      register: async (username, email, password, referralCode = null) => {
        set({ isLoading: true, error: null });
        try {
          // Prepare user metadata
          const metadata: Record<string, any> = { username };
          
          // Add referral code to metadata if provided
          if (referralCode) {
            metadata.referral_code = referralCode;
          }
          
          // Register the user
          const { data, error } = await supabase.auth.signUp({
            email,
            password,
            options: {
              data: metadata,
            },
          });
          
          if (error) throw error;
          
          // Update the user_profiles table with username and referrer if applicable
          if (data.user) {
            const profileData: Record<string, any> = { 
              username,
              referrer_id: referralCode // This will be null if no referral code
            };
            
            const { error: profileError } = await supabase.from('user_profiles')
              .update(profileData)
              .eq('id', data.user.id);
            
            if (profileError) {
              console.error('Error updating profile:', profileError);
            }
          }
          
          // Get user profile data
          const user = await getCurrentUser();
          
          if (!user) {
            throw new Error('Failed to get user information');
          }
          
          set({ 
            user,
            token: data.session?.access_token || null,
            isAuthenticated: !!data.session,
            isLoading: false,
            error: null
          });
        } catch (error) {
          set({ 
            error: error instanceof Error ? error.message : 'Registration failed', 
            isLoading: false,
            isAuthenticated: false
          });
          throw error;
        }
      },
      
      logout: async () => {
        await supabase.auth.signOut();
        set({ 
          user: null, 
          token: null, 
          isAuthenticated: false 
        });
      },
      
      resetPassword: async (email) => {
        set({ isLoading: true, error: null });
        try {
          const { error } = await supabase.auth.resetPasswordForEmail(email);
          
          if (error) throw error;
          
          set({ isLoading: false, error: null });
        } catch (error) {
          set({ 
            error: error instanceof Error ? error.message : 'Password reset failed', 
            isLoading: false 
          });
          throw error;
        }
      },
      
      refreshUser: async () => {
        try {
          const user = await getCurrentUser();
          
          if (user) {
            set({ 
              user,
              isAuthenticated: true,
              error: null
            });
          } else {
            set({ 
              user: null, 
              token: null, 
              isAuthenticated: false 
            });
          }
        } catch (error) {
          console.error('Error refreshing user:', error);
          set({ 
            error: error instanceof Error ? error.message : 'Failed to refresh user',
            isAuthenticated: false
          });
        }
      },
      
      clearError: () => set({ error: null }),
    }),
    {
      name: 'auth-storage',
      // Only store non-sensitive data
      partialize: (state) => ({
        token: state.token,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);

// Initialize by checking the current session
export const initializeAuth = async () => {
  const { refreshUser } = useAuthStore.getState();
  await refreshUser();
};