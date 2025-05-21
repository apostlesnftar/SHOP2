// This file is a wrapper around all our service functions
// to provide a centralized API for our application

export * from './user-service';
export * from './product-service';
export * from './order-service';
export * from './agent-service';

// Re-export supabase client for direct access when needed
export { supabase, getCurrentUser } from '../lib/supabase';