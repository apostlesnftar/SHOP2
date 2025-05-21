/*
  # User Triggers
  
  1. Functions and Triggers
    - Create trigger to automatically create user_profile when a new user signs up
    - Ensure proper role assignment
    - Handle agent creation
*/

-- Function to create a user profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, username, role)
  VALUES (NEW.id, NEW.email, 'customer');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile after signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Function to automatically create agent record when a user is promoted to agent
CREATE OR REPLACE FUNCTION handle_agent_promotion()
RETURNS TRIGGER AS $$
BEGIN
  -- Only execute if role changed to 'agent'
  IF NEW.role = 'agent' AND (OLD.role IS NULL OR OLD.role <> 'agent') THEN
    -- Create agent record with default values if it doesn't exist
    INSERT INTO agents (user_id, level, commission_rate)
    VALUES (NEW.id, 1, 5.0)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to handle agent promotion
CREATE TRIGGER on_user_promoted_to_agent
  AFTER UPDATE OF role ON user_profiles
  FOR EACH ROW
  WHEN (NEW.role = 'agent' AND (OLD.role IS NULL OR OLD.role <> 'agent'))
  EXECUTE FUNCTION handle_agent_promotion();

-- Function to handle commission calculation on order completion
CREATE OR REPLACE FUNCTION process_agent_commission()
RETURNS TRIGGER AS $$
DECLARE
  order_user_id UUID;
  agent_user_id UUID;
  parent_agent_id UUID;
  order_total DECIMAL;
  agent_commission_rate DECIMAL;
  parent_commission_rate DECIMAL;
  agent_commission DECIMAL;
  parent_commission DECIMAL;
BEGIN
  -- Only process if order status changed to 'delivered'
  IF NEW.status = 'delivered' AND OLD.status <> 'delivered' THEN
    -- Get order user and total
    SELECT user_id, total INTO order_user_id, order_total FROM orders WHERE id = NEW.id;
    
    -- Find the agent associated with this user (through parent_agent_id)
    SELECT a.user_id, a.parent_agent_id, a.commission_rate 
    INTO agent_user_id, parent_agent_id, agent_commission_rate
    FROM user_profiles up
    LEFT JOIN agents a ON a.user_id = up.id
    WHERE up.id = order_user_id;
    
    -- If the user is associated with an agent
    IF agent_user_id IS NOT NULL THEN
      -- Calculate commission
      agent_commission := (order_total * agent_commission_rate / 100);
      
      -- Create commission record
      INSERT INTO commissions (agent_id, order_id, amount, status)
      VALUES (agent_user_id, NEW.id, agent_commission, 'pending');
      
      -- Update agent total earnings and balance
      UPDATE agents
      SET total_earnings = total_earnings + agent_commission,
          current_balance = current_balance + agent_commission
      WHERE user_id = agent_user_id;
      
      -- If there's a parent agent, calculate their commission too
      IF parent_agent_id IS NOT NULL THEN
        -- Get parent's commission rate
        SELECT commission_rate INTO parent_commission_rate
        FROM agents WHERE user_id = parent_agent_id;
        
        parent_commission := (order_total * parent_commission_rate / 200); -- Half the normal rate for the parent
        
        -- Create commission record for parent
        INSERT INTO commissions (agent_id, order_id, amount, status)
        VALUES (parent_agent_id, NEW.id, parent_commission, 'pending');
        
        -- Update parent agent total earnings and balance
        UPDATE agents
        SET total_earnings = total_earnings + parent_commission,
            current_balance = current_balance + parent_commission
        WHERE user_id = parent_agent_id;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to process commissions on order delivery
CREATE TRIGGER on_order_delivered
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  WHEN (NEW.status = 'delivered' AND OLD.status <> 'delivered')
  EXECUTE FUNCTION process_agent_commission();