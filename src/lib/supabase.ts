import { createClient } from '@supabase/supabase-js';
import { Database } from '../types/supabase';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables. Please check your .env file.');
}

// Create client with retry configuration and better error handling
export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true
  },
  global: {
    headers: {
      'x-application-name': 'ecommerce-app'
    }
  },
  db: {
    schema: 'public'
  },
  // Add retries for better reliability
  realtime: {
    params: {
      eventsPerSecond: 2
    }
  }
});

// Test connection and provide detailed error
export const testConnection = async () => {
  try {
    const { data, error } = await supabase.from('user_profiles').select('count').limit(1);
    
    if (error) {
      // Provide more detailed error information
      const errorDetails = {
        message: error.message,
        code: error.code,
        details: error.details,
        hint: error.hint
      };
      console.error('Supabase connection error:', errorDetails);
      throw new Error(`Failed to connect to Supabase: ${error.message}`);
    }
    
    return true;
  } catch (error) {
    // Handle network errors and other exceptions
    if (error instanceof Error) {
      if (error.message.includes('Failed to fetch')) {
        throw new Error('Unable to reach Supabase server. Please check your internet connection and Supabase configuration.');
      }
      throw new Error(`Supabase connection error: ${error.message}`);
    }
    throw error;
  }
};

// Helper function to check Supabase connection status
export const isSupabaseConnected = async () => {
  try {
    await testConnection();
    return true;
  } catch (error) {
    console.error('Supabase connection check failed:', error);
    return false;
  }
};

// Safe query wrapper with error handling
export const safeQuery = async <T>(
  queryName: string,
  query: Promise<{ data: T | null; error: any }>
): Promise<{ data: T | null; error: any }> => {
  try {
    const { data, error } = await query;
    
    if (error) {
      console.error(`Error in ${queryName} query:`, error);
      throw error;
    }
    
    return { data, error: null };
  } catch (error) {
    console.error(`Failed to execute ${queryName} query:`, error);
    return { data: null, error };
  }
};

export const getServerTimestamp = async () => {
  try {
    const { data, error } = await supabase.rpc('get_server_timestamp');
    if (error) throw error;
    return data;
  } catch (error) {
    console.error('Error fetching server timestamp:', error);
    throw error;
  }
};

// Helper to get active user with profile data in one call
export const getCurrentUser = async () => {
  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    
    if (userError || !user) {
      return null;
    }
    
    // Get user profile
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('id', user.id)
      .single();
    
    if (profileError) {
      console.error('Error fetching user profile:', profileError);
      return null;
    }
    
    return {
      id: user.id,
      email: user.email,
      username: profile?.username || user.email?.split('@')[0],
      fullName: profile?.full_name,
      profileImage: profile?.profile_image,
      role: profile?.role,
      createdAt: profile?.created_at
    };
  } catch (error) {
    console.error('Error in getCurrentUser:', error);
    return null;
  }
};