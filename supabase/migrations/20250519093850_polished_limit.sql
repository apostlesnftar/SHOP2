/*
  # Database Utility Functions
  
  1. Functions
    - get_server_timestamp - Get the current server timestamp
    - get_effective_price - Calculate the effective price of a product with discount
*/

-- Function to get the current server timestamp
CREATE OR REPLACE FUNCTION get_server_timestamp()
RETURNS TIMESTAMPTZ AS $$
BEGIN
  RETURN now();
END;
$$ LANGUAGE plpgsql;

-- Function to calculate the effective price of a product with discount
CREATE OR REPLACE FUNCTION get_effective_price(product_id UUID)
RETURNS DECIMAL AS $$
DECLARE
  product_price DECIMAL;
  product_discount INTEGER;
  effective_price DECIMAL;
BEGIN
  SELECT price, discount INTO product_price, product_discount
  FROM products
  WHERE id = product_id;
  
  IF product_discount IS NULL OR product_discount = 0 THEN
    effective_price := product_price;
  ELSE
    effective_price := product_price * (1 - product_discount::DECIMAL / 100);
  END IF;
  
  RETURN effective_price;
END;
$$ LANGUAGE plpgsql;