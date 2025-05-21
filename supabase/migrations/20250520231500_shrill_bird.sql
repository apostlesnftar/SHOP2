/*
  # Add updated_at column to shared_orders table

  1. Changes
    - Add `updated_at` column to `shared_orders` table with default value of now()
    - Add trigger to automatically update `updated_at` when row is modified

  2. Purpose
    - Enable audit tracking of when shared orders are modified
    - Support RPC functions that need to update this timestamp
*/

-- Add updated_at column
ALTER TABLE shared_orders 
ADD COLUMN updated_at timestamptz DEFAULT now() NOT NULL;

-- Add trigger to automatically update updated_at
CREATE TRIGGER update_shared_orders_modtime 
    BEFORE UPDATE ON shared_orders 
    FOR EACH ROW 
    EXECUTE FUNCTION update_modified_column();