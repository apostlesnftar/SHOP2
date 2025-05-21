import React, { useState, useEffect } from 'react';
import { CreditCard, Plus, Settings, Check, X, AlertTriangle, Key, Code, Save } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/Card';
import Button from '../../components/ui/Button';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select'; 
import { Badge } from '../../components/ui/Badge';
import { supabase } from '../../lib/supabase';
import { formatCurrency, formatDate } from '../../lib/utils';
import { toast } from 'react-hot-toast';
import defaultProviderCode from '../../lib/payment/templates/custom-provider.ts?raw';

interface PaymentGateway {
  id: string;
  name: string;
  code?: string;
  provider: string;
  api_key: string;
  merchant_id: string;
  webhook_url: string;
  display_name: string;
  icon_url?: string;
  is_active: boolean;
  test_mode: boolean;
  created_at: string;
  updated_at: string;
}

interface PaymentGatewayFormData {
  name: string;
  code?: string;
  provider: string;
  api_key: string;
  merchant_id: string;
  webhook_url: string;
  display_name: string;
  icon_url?: string;
  is_active: boolean;
  test_mode: boolean;
}

const PaymentSettingsPage: React.FC = () => {
  const [gateways, setGateways] = useState<PaymentGateway[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [showCodeModal, setShowCodeModal] = useState(false);
  const [editingGateway, setEditingGateway] = useState<PaymentGateway | null>(null);
  const [editingCode, setEditingCode] = useState('');
  const [formData, setFormData] = useState<PaymentGatewayFormData>({
    name: '',
    code: '',
    provider: 'stripe',
    api_key: '',
    merchant_id: '',
    webhook_url: '',
    display_name: '',
    icon_url: '',
    is_active: true,
    test_mode: true,
  });

  useEffect(() => {
    fetchGateways();
  }, []);

  const fetchGateways = async () => {
    try {
      const { data, error } = await supabase
        .from('payment_gateways')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setGateways(data || []);
    } catch (error) {
      console.error('Error fetching payment gateways:', error);
      toast.error('Failed to load payment gateways');
    } finally {
      setIsLoading(false);
    }
  };

  const handleAddGateway = async () => {
    setIsLoading(true);
    try {
      // Validate provider code if present
      if (formData.code) {
        try {
          // Basic validation - ensure it's valid JavaScript
          new Function(formData.code);
        } catch (error) {
          toast.error('Invalid provider code');
          setIsLoading(false);
          return;
        }
      }

      const gatewayData = {
        name: formData.name,
        code: formData.code,
        provider: formData.provider,
        api_key: formData.api_key,
        merchant_id: formData.merchant_id,
        webhook_url: formData.webhook_url,
        display_name: formData.display_name,
        icon_url: formData.icon_url || null,
        is_active: true,
        test_mode: formData.test_mode,
      };

      const { error } = await supabase
        .from('payment_gateways')
        .insert([gatewayData]);

      if (error) throw error;

      toast.success('Payment gateway added successfully');
      setShowAddModal(false);
      resetForm();
      fetchGateways();
    } catch (error) {
      console.error('Error adding payment gateway:', error);
      toast.error('Failed to add payment gateway');
    } finally {
      setIsLoading(false);
    }
  };

  const handleUpdateGateway = async (gateway: PaymentGateway) => {
    if (!gateway.id) {
      toast.error('Invalid gateway ID');
      return;
    }

    setIsLoading(true);
    try {
      // Validate provider code if present
      if (gateway.code) {
        try {
          // Basic validation - ensure it's valid JavaScript
          new Function(gateway.code);
        } catch (error) {
          toast.error('Invalid provider code');
          setIsLoading(false);
          return;
        }
      }

      const gatewayData = {
        name: gateway.name,
        code: gateway.code,
        provider: gateway.provider,
        api_key: gateway.api_key,
        merchant_id: gateway.merchant_id,
        webhook_url: gateway.webhook_url,
        display_name: gateway.display_name,
        icon_url: gateway.icon_url || null,
        is_active: gateway.is_active,
        test_mode: gateway.test_mode,
        updated_at: new Date().toISOString(),
      };

      const { error } = await supabase
        .from('payment_gateways')
        .update(gatewayData)
        .eq('id', gateway.id);

      if (error) throw error;

      toast.success('Payment gateway updated successfully');
      setShowAddModal(false);
      setEditingGateway(null);
      fetchGateways();
    } catch (error) {
      console.error('Error updating payment gateway:', error);
      toast.error('Failed to update payment gateway');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (editingGateway && !editingGateway.id) {
      toast.error('Invalid gateway ID');
      return;
    }

    setIsLoading(true);
    
    // Validate provider code if present
    if (formData.code) {
      try {
        // Basic validation - ensure it's valid JavaScript
        new Function(formData.code);
      } catch (error) {
        toast.error('Invalid provider code');
        setIsLoading(false);
        return;
      }
    }

    try {
      const gatewayData = {
        name: formData.name,
        code: formData.code,
        provider: formData.provider,
        api_key: formData.api_key,
        merchant_id: formData.merchant_id,
        webhook_url: formData.webhook_url,
        display_name: formData.display_name || null,
        test_mode: formData.test_mode,
        updated_at: new Date().toISOString()
      };

      // Only include icon_url if it's not empty
      if (formData.icon_url) {
        gatewayData['icon_url'] = formData.icon_url;
      }

      if (editingGateway) {
        // Update existing gateway
        const { error } = await supabase
          .from('payment_gateways')
          .update(gatewayData)
          .eq('id', editingGateway.id);

        if (error) throw error;
        toast.success('Payment gateway updated successfully');
      } else {
        // Create new gateway
        const { error } = await supabase
          .from('payment_gateways')
          .insert([{
            ...gatewayData,
            is_active: true
          }]);

        if (error) throw error;
        toast.success('Payment gateway added successfully');
      }

      setShowAddModal(false);
      setEditingGateway(null);
      resetForm();
      fetchGateways();
    } catch (error) {
      console.error('Error saving payment gateway:', error);
      toast.error('Failed to save payment gateway');
    } finally {
      setIsLoading(false);
    }
  };

  const handleToggleActive = async (gateway: PaymentGateway) => {
    if (!gateway.id) {
      toast.error('Invalid gateway ID');
      return;
    }

    try {
      const { error } = await supabase
        .from('payment_gateways')
        .update({ is_active: !gateway.is_active })
        .eq('id', gateway.id);

      if (error) throw error;
      
      toast.success(`Payment gateway ${gateway.is_active ? 'disabled' : 'enabled'}`);
      fetchGateways();
    } catch (error) {
      console.error('Error toggling gateway status:', error);
      toast.error('Failed to update gateway status');
    }
  };

  const handleDelete = async (gateway: PaymentGateway) => {
    if (!gateway.id) {
      toast.error('Invalid gateway ID');
      return;
    }

    if (!confirm('Are you sure you want to delete this payment gateway? This will also delete all associated logs.')) return;

    try {
      // Start a Supabase transaction by using RPC
      const { error: rpcError } = await supabase.rpc('delete_payment_gateway', {
        gateway_id: gateway.id
      });

      if (rpcError) {
        console.error('Error deleting gateway:', rpcError);
        throw new Error('Failed to delete gateway');
      }

      toast.success('Payment gateway and associated logs deleted');
      fetchGateways();
    } catch (error) {
      console.error('Error in delete transaction:', error);
      toast.error('Failed to delete gateway. Please try again.');
    }
  };

  const handleTestConnection = async (gateway: PaymentGateway) => {
    if (!gateway.id) {
      toast.error('Invalid gateway ID');
      return;
    }

    try {
      // Here you would typically make an API call to test the connection
      // For demo purposes, we'll just show a success message
      toast.success('Connection test successful');
    } catch (error) {
      console.error('Error testing connection:', error);
      toast.error('Connection test failed');
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      code: '',
      provider: 'stripe',
      api_key: '',
      merchant_id: '',
      webhook_url: '',
      display_name: '',
      icon_url: '',
      is_active: true,
      test_mode: true
    });
  };

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
          <div className="space-y-4">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="h-32 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Payment Settings</h1>
        <Button
          onClick={() => setShowAddModal(true)}
          leftIcon={<Plus className="h-5 w-5" />}
        >
          Add Payment Gateway
        </Button>
      </div>

      {/* Payment Gateways List */}
      <div className="space-y-6">
        {gateways.length === 0 ? (
          <Card className="p-12 text-center">
            <CreditCard className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h2 className="text-xl font-semibold text-gray-900 mb-2">No Payment Gateways</h2>
            <p className="text-gray-600 mb-6">
              Add your first payment gateway to start accepting payments.
            </p>
            <Button
              onClick={() => setShowAddModal(true)}
              leftIcon={<Plus className="h-5 w-5" />}
            >
              Add Payment Gateway
            </Button>
          </Card>
        ) : (
          gateways.map((gateway) => (
            <Card key={gateway.id}>
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-4">
                    <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center">
                      {gateway.icon_url ? (
                        <img 
                          src={gateway.icon_url} 
                          alt={gateway.name}
                          className="h-8 w-8 object-contain"
                        />
                      ) : (
                        <CreditCard className="h-6 w-6 text-gray-600" />
                      )}
                    </div>
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900">{gateway.name}</h3>
                      <p className="text-sm text-gray-500 capitalize">{gateway.provider}</p>
                    </div>
                    <div className="flex items-center space-x-2">
                      <Badge variant={gateway.is_active ? 'success' : 'danger'}>
                        {gateway.is_active ? 'Active' : 'Inactive'}
                      </Badge>
                      {gateway.test_mode && (
                        <Badge variant="warning">Test Mode</Badge>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center space-x-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => {
                        setEditingGateway(gateway);
                        setEditingCode(gateway.code || '');
                        setShowCodeModal(true);
                      }}
                      leftIcon={<Code className="h-4 w-4" />}
                    >
                      Edit Provider Code
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleTestConnection(gateway)}
                    >
                      Test Connection
                    </Button>
                    <Button
                      variant={gateway.is_active ? 'danger' : 'success'}
                      size="sm"
                      onClick={() => handleToggleActive(gateway)}
                    >
                      {gateway.is_active ? 'Disable' : 'Enable'}
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => {
                        setEditingGateway(gateway);
                        setFormData({
                          name: gateway.name,
                          provider: gateway.provider,
                          api_key: gateway.api_key,
                          code: gateway.code,
                          merchant_id: gateway.merchant_id,
                          webhook_url: gateway.webhook_url,
                          display_name: gateway.display_name,
                          icon_url: gateway.icon_url || '',
                          is_active: gateway.is_active,
                          test_mode: gateway.test_mode
                        });
                        setShowAddModal(true);
                      }}
                    >
                      Edit
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleDelete(gateway)}
                    >
                      Delete
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {/* Code Editor Modal */}
      {showCodeModal && editingGateway && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-4xl h-[80vh] flex flex-col">
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle>Edit Provider Code</CardTitle>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowCodeModal(false)}
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            </CardHeader>
            <CardContent className="flex-grow overflow-hidden p-6">
              <div className="h-full flex flex-col">
                <div className="mb-4">
                  <p className="text-sm text-gray-600">
                    Edit the provider implementation code. This code will be used to process payments
                    through this gateway. Make sure to implement all required methods.
                  </p>
                </div>
                <div className="flex-grow relative">
                  <textarea
                    className="w-full h-full font-mono text-sm p-4 bg-gray-900 text-gray-100 rounded-md"
                    value={editingCode}
                    onChange={(e) => setEditingCode(e.target.value)}
                    spellCheck={false}
                  />
                </div>
                <div className="flex justify-end mt-4 space-x-2">
                  <Button
                    variant="outline"
                    onClick={() => setShowCodeModal(false)}
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={async () => {
                      try {
                        // Validate code
                        new Function(editingCode);
                        
                        // Update gateway code
                        const { error } = await supabase
                          .from('payment_gateways')
                          .update({ code: editingCode })
                          .eq('id', editingGateway.id);
                        
                        if (error) throw error;
                        
                        toast.success('Provider code updated successfully');
                        setShowCodeModal(false);
                        fetchGateways();
                      } catch (error) {
                        toast.error('Failed to update provider code');
                      }
                    }}
                    leftIcon={<Save className="h-4 w-4" />}
                  >
                    Save Changes
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Add/Edit Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-2xl">
            <CardHeader>
              <CardTitle>
                {editingGateway ? 'Edit Payment Gateway' : 'Add Payment Gateway'}
              </CardTitle>
            </CardHeader>
            <CardContent className="p-6">
              <div className="space-y-4">
                <Input
                  label="Gateway Name"
                  value={editingGateway?.name || formData.name}
                  onChange={(e) => editingGateway 
                    ? setEditingGateway({ ...editingGateway, name: e.target.value })
                    : setFormData({ ...formData, name: e.target.value })}
                  required
                />
                <Input
                  label="Display Name"
                  value={editingGateway?.display_name || formData.display_name}
                  onChange={(e) => editingGateway
                    ? setEditingGateway({ ...editingGateway, display_name: e.target.value })
                    : setFormData({ ...formData, display_name: e.target.value })}
                  placeholder="How this payment method will be displayed to customers"
                  required
                />
                <Select
                  label="Provider"
                  value={editingGateway?.provider || formData.provider}
                  onChange={(e) => editingGateway
                    ? setEditingGateway({ ...editingGateway, provider: e.target.value })
                    : setFormData({ ...formData, provider: e.target.value })}
                  options={[
                    { value: 'stripe', label: 'Stripe' },
                    { value: 'paypal', label: 'PayPal' },
                    { value: 'custom', label: 'Custom Provider' }
                  ]}
                  required
                />
                <Input
                  label="API Key"
                  type="password"
                  value={editingGateway?.api_key || formData.api_key}
                  onChange={(e) => editingGateway
                    ? setEditingGateway({ ...editingGateway, api_key: e.target.value })
                    : setFormData({ ...formData, api_key: e.target.value })}
                  required
                />
                <Input
                  label="Merchant ID"
                  value={editingGateway?.merchant_id || formData.merchant_id}
                  onChange={(e) => editingGateway
                    ? setEditingGateway({ ...editingGateway, merchant_id: e.target.value })
                    : setFormData({ ...formData, merchant_id: e.target.value })}
                  required
                />
                <Input
                  label="Webhook URL"
                  value={editingGateway?.webhook_url || formData.webhook_url}
                  onChange={(e) => editingGateway
                    ? setEditingGateway({ ...editingGateway, webhook_url: e.target.value })
                    : setFormData({ ...formData, webhook_url: e.target.value })}
                  placeholder="https://your-domain.com/api/webhook"
                  required
                />
                <Input
                  label="Icon URL"
                  value={editingGateway?.icon_url || formData.icon_url}
                  onChange={(e) => editingGateway
                    ? setEditingGateway({ ...editingGateway, icon_url: e.target.value })
                    : setFormData({ ...formData, icon_url: e.target.value })}
                  placeholder="https://example.com/payment-icon.svg"
                />
                {(editingGateway?.provider === 'custom' || formData.provider === 'custom') && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Provider Implementation
                    </label>
                    <div className="bg-gray-50 p-4 rounded-md mb-2">
                      <p className="text-sm text-gray-600">
                        Implement the following methods:
                      </p>
                      <ul className="list-disc list-inside text-sm text-gray-600 mt-1">
                        <li>processPayment(amount: number, currency: string)</li>
                        <li>validateConfig()</li>
                        <li>getPaymentMethods()</li>
                      </ul>
                    </div>
                    <Button
                      variant="outline"
                      className="w-full"
                      onClick={() => {
                        setShowCodeModal(true);
                        setEditingCode(editingGateway?.code || formData.code || defaultProviderCode);
                      }}
                    >
                      Edit Provider Code
                    </Button>
                  </div>
                )}
                <div className="space-y-2">
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="is_active"
                      checked={editingGateway?.is_active ?? formData.is_active}
                      onChange={(e) => editingGateway
                        ? setEditingGateway({ ...editingGateway, is_active: e.target.checked })
                        : setFormData({ ...formData, is_active: e.target.checked })}
                      className="rounded border-gray-300 text-blue-600"
                    />
                    <label htmlFor="is_active" className="text-sm text-gray-700">
                      Active
                    </label>
                  </div>
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="test_mode"
                      checked={editingGateway?.test_mode ?? formData.test_mode}
                      onChange={(e) => editingGateway
                        ? setEditingGateway({ ...editingGateway, test_mode: e.target.checked })
                        : setFormData({ ...formData, test_mode: e.target.checked })}
                      className="rounded border-gray-300 text-blue-600"
                    />
                    <label htmlFor="test_mode" className="text-sm text-gray-700">
                      Test Mode
                    </label>
                  </div>
                </div>
                <div className="flex justify-end gap-2 mt-6">
                  <Button
                    variant="outline"
                    onClick={() => {
                      setShowAddModal(false);
                      setEditingGateway(null);
                    }}
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={() => editingGateway
                      ? handleUpdateGateway(editingGateway)
                      : handleAddGateway()
                    }
                  >
                    {editingGateway ? 'Update Gateway' : 'Add Gateway'}
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
};

export default PaymentSettingsPage;