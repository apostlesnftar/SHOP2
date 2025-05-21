-- Update process_agent_commission function to trigger on 'processing' status
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
  referrer_id UUID;
  v_transaction_id UUID;
  v_parent_transaction_id UUID;
  v_order_number TEXT;
BEGIN
  -- Only process if order status changed to 'processing' (instead of 'delivered')
  IF NEW.status = 'processing' AND OLD.status <> 'processing' THEN
    -- Get order user, number and total
    SELECT user_id, order_number, total INTO order_user_id, v_order_number, order_total FROM orders WHERE id = NEW.id;
    
    -- First check if the user has a referrer (direct referral relationship)
    SELECT referrer_id INTO referrer_id
    FROM user_profiles
    WHERE id = order_user_id;
    
    -- If user has a referrer, create commission for the referrer
    IF referrer_id IS NOT NULL THEN
      -- Get the referrer's commission rate
      SELECT commission_rate, parent_agent_id INTO agent_commission_rate, parent_agent_id
      FROM agents
      WHERE user_id = referrer_id;
      
      -- If referrer is an agent, calculate commission
      IF agent_commission_rate IS NOT NULL THEN
        -- Calculate commission
        agent_commission := (order_total * agent_commission_rate / 100);
        
        -- Create commission record
        INSERT INTO commissions (agent_id, order_id, amount, status)
        VALUES (referrer_id, NEW.id, agent_commission, 'pending');
        
        -- Create wallet transaction record
        INSERT INTO wallet_transactions (
          agent_id,
          amount,
          type,
          status,
          reference_id,
          notes,
          completed_at
        ) VALUES (
          referrer_id,
          agent_commission,
          'commission',
          'completed',
          NEW.id,
          'Commission from order #' || v_order_number,
          NOW()
        ) RETURNING id INTO v_transaction_id;
        
        -- Update agent total earnings and balance
        UPDATE agents
        SET total_earnings = total_earnings + agent_commission,
            current_balance = current_balance + agent_commission
        WHERE user_id = referrer_id;
        
        -- Get parent agent if exists
        SELECT parent_agent_id INTO parent_agent_id
        FROM agents
        WHERE user_id = referrer_id;
        
        -- If there's a parent agent, calculate their commission too
        IF parent_agent_id IS NOT NULL THEN
          -- Get parent's commission rate
          SELECT commission_rate INTO parent_commission_rate
          FROM agents WHERE user_id = parent_agent_id;
          
          parent_commission := (order_total * parent_commission_rate / 200); -- Half the normal rate for the parent
          
          -- Create commission record for parent
          INSERT INTO commissions (agent_id, order_id, amount, status)
          VALUES (parent_agent_id, NEW.id, parent_commission, 'pending');
          
          -- Create wallet transaction record for parent
          INSERT INTO wallet_transactions (
            agent_id,
            amount,
            type,
            status,
            reference_id,
            notes,
            completed_at
          ) VALUES (
            parent_agent_id,
            parent_commission,
            'commission',
            'completed',
            NEW.id,
            'Team commission from order #' || v_order_number,
            NOW()
          ) RETURNING id INTO v_parent_transaction_id;
          
          -- Update parent agent total earnings and balance
          UPDATE agents
          SET total_earnings = total_earnings + parent_commission,
              current_balance = current_balance + parent_commission
          WHERE user_id = parent_agent_id;
        END IF;
      END IF;
    ELSE
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
        
        -- Create wallet transaction record
        INSERT INTO wallet_transactions (
          agent_id,
          amount,
          type,
          status,
          reference_id,
          notes,
          completed_at
        ) VALUES (
          agent_user_id,
          agent_commission,
          'commission',
          'completed',
          NEW.id,
          'Commission from order #' || v_order_number,
          NOW()
        ) RETURNING id INTO v_transaction_id;
        
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
          
          -- Create wallet transaction record for parent
          INSERT INTO wallet_transactions (
            agent_id,
            amount,
            type,
            status,
            reference_id,
            notes,
            completed_at
          ) VALUES (
            parent_agent_id,
            parent_commission,
            'commission',
            'completed',
            NEW.id,
            'Team commission from order #' || v_order_number,
            NOW()
          ) RETURNING id INTO v_parent_transaction_id;
          
          -- Update parent agent total earnings and balance
          UPDATE agents
          SET total_earnings = total_earnings + parent_commission,
              current_balance = current_balance + parent_commission
          WHERE user_id = parent_agent_id;
        END IF;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if triggers exist before trying to create them
DO $$
BEGIN
  -- Drop existing triggers if they exist
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_order_processing' AND tgrelid = 'orders'::regclass) THEN
    RAISE NOTICE 'Dropping existing on_order_processing trigger';
    DROP TRIGGER on_order_processing ON orders;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_order_delivered' AND tgrelid = 'orders'::regclass) THEN
    RAISE NOTICE 'Dropping existing on_order_delivered trigger';
    DROP TRIGGER on_order_delivered ON orders;
  END IF;
END $$;

-- Create new trigger for processing orders
CREATE TRIGGER on_order_processing
  AFTER UPDATE OF status ON orders
  FOR EACH ROW
  WHEN (NEW.status = 'processing' AND OLD.status <> 'processing')
  EXECUTE FUNCTION process_agent_commission();

-- Grant execute permission
GRANT EXECUTE ON FUNCTION process_agent_commission() TO authenticated;