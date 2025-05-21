/*
  # Add icon_url column to payment_gateways table

  1. Changes
    - Add `icon_url` column to `payment_gateways` table
      - Type: text
      - Nullable: true
      - No default value

  2. Security
    - No changes to RLS policies needed
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payment_gateways' 
    AND column_name = 'icon_url'
  ) THEN
    ALTER TABLE payment_gateways ADD COLUMN icon_url text;
  END IF;
END $$;