export interface Database {
  public: {
    Tables: {
      categories: {
        Row: {
          id: string;
          name: string;
          description: string | null;
          image_url: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          description?: string | null;
          image_url?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          description?: string | null;
          image_url?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      products: {
        Row: {
          id: string;
          name: string;
          description: string | null;
          price: number;
          images: string[];
          category_id: string | null;
          inventory: number;
          discount: number | null;
          featured: boolean | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          description?: string | null;
          price: number;
          images?: string[];
          category_id?: string | null;
          inventory?: number;
          discount?: number | null;
          featured?: boolean | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          description?: string | null;
          price?: number;
          images?: string[];
          category_id?: string | null;
          inventory?: number;
          discount?: number | null;
          featured?: boolean | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      user_profiles: {
        Row: {
          id: string;
          username: string | null;
          full_name: string | null;
          profile_image: string | null;
          phone: string | null;
          role: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          username?: string | null;
          full_name?: string | null;
          profile_image?: string | null;
          phone?: string | null;
          role?: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          username?: string | null;
          full_name?: string | null;
          profile_image?: string | null;
          phone?: string | null;
          role?: string;
          created_at?: string;
          updated_at?: string;
        };
      };
      addresses: {
        Row: {
          id: string;
          user_id: string;
          name: string;
          address_line1: string;
          address_line2: string | null;
          city: string;
          state: string;
          postal_code: string;
          country: string;
          phone: string;
          is_default: boolean | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          name: string;
          address_line1: string;
          address_line2?: string | null;
          city: string;
          state: string;
          postal_code: string;
          country: string;
          phone: string;
          is_default?: boolean | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          name?: string;
          address_line1?: string;
          address_line2?: string | null;
          city?: string;
          state?: string;
          postal_code?: string;
          country?: string;
          phone?: string;
          is_default?: boolean | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      orders: {
        Row: {
          id: string;
          order_number: string;
          user_id: string;
          status: string;
          shipping_address_id: string | null;
          payment_method: string;
          payment_status: string;
          subtotal: number;
          tax: number;
          shipping: number;
          total: number;
          tracking_number: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          order_number: string;
          user_id: string;
          status?: string;
          shipping_address_id?: string | null;
          payment_method: string;
          payment_status?: string;
          subtotal: number;
          tax: number;
          shipping: number;
          total: number;
          tracking_number?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          order_number?: string;
          user_id?: string;
          status?: string;
          shipping_address_id?: string | null;
          payment_method?: string;
          payment_status?: string;
          subtotal?: number;
          tax?: number;
          shipping?: number;
          total?: number;
          tracking_number?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      order_items: {
        Row: {
          id: string;
          order_id: string;
          product_id: string;
          quantity: number;
          price: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          order_id: string;
          product_id: string;
          quantity: number;
          price: number;
          created_at?: string;
        };
        Update: {
          id?: string;
          order_id?: string;
          product_id?: string;
          quantity?: number;
          price?: number;
          created_at?: string;
        };
      };
      agents: {
        Row: {
          user_id: string;
          level: number;
          parent_agent_id: string | null;
          commission_rate: number;
          total_earnings: number;
          current_balance: number;
          status: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          level?: number;
          parent_agent_id?: string | null;
          commission_rate?: number;
          total_earnings?: number;
          current_balance?: number;
          status?: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          user_id?: string;
          level?: number;
          parent_agent_id?: string | null;
          commission_rate?: number;
          total_earnings?: number;
          current_balance?: number;
          status?: string;
          created_at?: string;
          updated_at?: string;
        };
      };
      commissions: {
        Row: {
          id: string;
          agent_id: string;
          order_id: string;
          amount: number;
          status: string;
          created_at: string;
          paid_at: string | null;
        };
        Insert: {
          id?: string;
          agent_id: string;
          order_id: string;
          amount: number;
          status?: string;
          created_at?: string;
          paid_at?: string | null;
        };
        Update: {
          id?: string;
          agent_id?: string;
          order_id?: string;
          amount?: number;
          status?: string;
          created_at?: string;
          paid_at?: string | null;
        };
      };
      shared_orders: {
        Row: {
          id: string;
          share_id: string;
          order_id: string;
          status: string;
          expires_at: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          share_id: string;
          order_id: string;
          status?: string;
          expires_at: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          share_id?: string;
          order_id?: string;
          status?: string;
          expires_at?: string;
          created_at?: string;
        };
      };
      wishlists: {
        Row: {
          id: string;
          user_id: string;
          product_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          product_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          product_id?: string;
          created_at?: string;
        };
      };
    };
    Views: {};
    Functions: {
      is_admin: {
        Args: Record<PropertyKey, never>;
        Returns: boolean;
      };
      is_agent: {
        Args: Record<PropertyKey, never>;
        Returns: boolean;
      };
    };
    Enums: {};
    CompositeTypes: {};
  };
}