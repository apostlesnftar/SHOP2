// Supabase Edge Function for handling Acacia Pay webhooks
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2.39.8";
import { createHash } from "npm:crypto";

// Create a Supabase client
const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Merchant key for signature verification
const MERCHANT_KEY = "Qc7ZCAAu63h2iMqwmDTjEizSDKejYIQPaKKofBC2ylmwgOts3iMvh8z9hughwvYxeod9bixBzrPgiVG6qC6QE91cEJaV47R6pyf9g4chXBWoZgLw27ZWzuO3nyX5KGi8";
const MERCHANT_NO = "M1747068935";
const APP_ID = "68222807cc36d1a5266b8589";
const DEBUG = false; // Set to false in production

// CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

// MD5 hash function
function md5(input: string): string {
  return createHash("md5").update(input).digest("hex").toUpperCase(); 
}

// Generate signature for Acacia Pay
function generateSignature(params: Record<string, any>): string {
  // Step 1: Sort parameters alphabetically
  const sortedParams = Object.keys(params)
    .filter(key => 
      key !== 'sign' && // Exclude sign parameter
      params[key] !== undefined && // Exclude undefined values
      params[key] !== null && // Exclude null values
      params[key] !== '' // Exclude empty strings
    )
    .sort()
    .reduce((acc: Record<string, any>, key) => {
      acc[key] = params[key];
      return acc;
    }, {});

  // Create string to sign
  const stringToSign = Object.entries(sortedParams)
    .map(([key, value]) => `${key}=${value}`)
    .join('&');

  // Step 2: Add merchant key
  const signString = `${stringToSign}&key=${MERCHANT_KEY}`;

  if (DEBUG) {
    console.log("String to sign:", signString);
  }

  // Generate MD5 hash
  return md5(signString);
}

// Verify signature from webhook
function verifySignature(params: Record<string, any>, signature: string): boolean {
  const calculatedSignature = generateSignature(params);
  
  if (DEBUG) {
    console.log("Calculated signature:", calculatedSignature);
    console.log("Received signature:", signature);
  }
  return calculatedSignature === signature;
}

// Update order status in database
async function updateOrderStatus(orderNumber: string, status: string): Promise<boolean> {
  try {
    // First get the order ID using the share ID
    const { data: sharedOrder, error: sharedOrderError } = await supabase
      .from('shared_orders')
      .select('order_id')
      .eq('share_id', orderNumber.replace('S', ''))
      .single();

    if (sharedOrderError || !sharedOrder) {
      console.error('Error finding shared order:', sharedOrderError);
      return false;
    }

    // Update the order status using the order ID
    const { error: updateError } = await supabase
      .from('orders')
      .update({ 
        status: status === 'SUCCESS' ? 'processing' : 'cancelled',
        payment_status: status === 'SUCCESS' ? 'completed' : 'failed'
      })
      .eq('id', sharedOrder.order_id);

    if (updateError) {
      console.error('Error updating order:', updateError);
      return false;
    }

    return true;
  } catch (error) {
    console.error('Error processing order update:', error);
    return false;
  }
}

// Main handler function
serve(async (req) => {
  console.log("Received webhook request", req.method);
  
  // Handle CORS preflight request
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }
  
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  
  try {
    console.log("Processing webhook request");
    // Parse request body
    let data;
    try {
      data = await req.json();
      console.log("Received webhook data:", JSON.stringify(data));
    } catch (e) {
      console.error("Error parsing JSON:", e);
      return new Response(JSON.stringify({ error: "Invalid JSON payload" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    
    // Log the raw data for debugging
    if (DEBUG) {
      console.log("Raw webhook data:", JSON.stringify(data));
    }
    
    // Verify signature
    const signature = data.sign;
    if (!signature) {
      return new Response(JSON.stringify({ error: "Missing signature" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    
    // Create a copy of data without the sign field
    const dataWithoutSign = { ...data };
    delete dataWithoutSign.sign;
    
    // Verify signature
    if (DEBUG === false && !verifySignature(dataWithoutSign, signature)) {
      console.error("Invalid signature");
      return new Response(JSON.stringify({ error: "Invalid signature" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    
    // Process the webhook based on the notification type
    const orderNumber = data.mchOrderNo;
    const status = data.orderState || data.state;
    console.log(`Processing order ${orderNumber} with status ${status}`);
    
    if (!orderNumber) {
      return new Response(JSON.stringify({ error: "Missing order number" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    
    console.log(`Updating order ${orderNumber} with status ${status}`);
    // Update order status in database
    const success = await updateOrderStatus(orderNumber, status);
    console.log(`Order update ${success ? 'successful' : 'failed'}`);
    
    if (!success) {
      return new Response(JSON.stringify({ error: "Failed to update order" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    
    // Return success response
    return new Response(JSON.stringify({
      success: true,
      message: `Order ${orderNumber} updated to ${status}`
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
    
  } catch (error) {
    console.error("Error processing webhook:", error instanceof Error ? error.message : error);
    
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});