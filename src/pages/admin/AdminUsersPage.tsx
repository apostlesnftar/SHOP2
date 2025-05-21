import React, { useState, useEffect } from 'react';
import { User, UserPlus, Edit, Trash2, Search } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/Card';
import Button from '../../components/ui/Button';
import Input from '../../components/ui/Input';
import Select from '../../components/ui/Select';
import { Badge } from '../../components/ui/Badge';
import { supabase } from '../../lib/supabase';
import { formatDate } from '../../lib/utils';
import { toast } from 'react-hot-toast';
import { useNavigate } from 'react-router-dom';

interface UserData {
  id: string;
  username: string;
  role: string;
  created_at: string;
  status: string;
}

const AdminUsersPage = () => {
  const [users, setUsers] = useState<UserData[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [showAddModal, setShowAddModal] = useState(false);
  const [newUserData, setNewUserData] = useState({
    email: '',
    username: '',
    role: 'customer',
    password: ''
  });
  const navigate = useNavigate();

  useEffect(() => {
    checkAdminAccess();
    fetchUsers();
  }, []);

  const checkAdminAccess = async () => {
    const { data: { user } } = await supabase.auth.getUser();
    
    if (!user) {
      navigate('/login');
      return;
    }

    const { data: profile } = await supabase
      .from('user_profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (!profile || profile.role !== 'admin') {
      navigate('/');
      toast.error('Access denied. Admin privileges required.');
      return;
    }
  };

  const fetchUsers = async () => {
    try {
      const { data: users, error } = await supabase
        .from('user_profiles')
        .select('id, username, role, created_at')
        .order('created_at', { ascending: false });

      if (error) throw error;

      const formattedUsers = users.map(user => ({
        id: user.id,
        username: user.username || 'N/A',
        role: user.role,
        created_at: user.created_at,
        status: 'active' // Since we can't access auth status, default to active
      }));

      setUsers(formattedUsers);
    } catch (error) {
      console.error('Error fetching users:', error);
      toast.error('Failed to load users');
    } finally {
      setIsLoading(false);
    }
  };

  const handleAddUser = async () => {
    try {
      const { data: { user }, error: signUpError } = await supabase.auth.signUp({
        email: newUserData.email,
        password: newUserData.password,
        options: {
          data: {
            username: newUserData.username
          }
        }
      });

      if (signUpError) throw signUpError;

      if (user) {
        const { error: profileError } = await supabase
          .from('user_profiles')
          .update({ 
            role: newUserData.role,
            username: newUserData.username 
          })
          .eq('id', user.id);

        if (profileError) throw profileError;

        toast.success('User created successfully');
        setShowAddModal(false);
        fetchUsers();
      }
    } catch (error) {
      console.error('Error creating user:', error);
      toast.error('Failed to create user');
    }
  };

  const handleUpdateRole = async (userId: string, newRole: string) => {
    try {
      const { error } = await supabase
        .from('user_profiles')
        .update({ role: newRole })
        .eq('id', userId);

      if (error) throw error;

      toast.success('User role updated');
      fetchUsers();
    } catch (error) {
      console.error('Error updating user role:', error);
      toast.error('Failed to update user role');
    }
  };

  const handleDeleteUser = async (userId: string) => {
    if (!confirm('Are you sure you want to delete this user?')) return;

    try {
      // Instead of deleting the auth user, we'll just update their role to 'inactive'
      const { error } = await supabase
        .from('user_profiles')
        .update({ role: 'inactive' })
        .eq('id', userId);

      if (error) throw error;

      toast.success('User deactivated successfully');
      fetchUsers();
    } catch (error) {
      console.error('Error deactivating user:', error);
      toast.error('Failed to deactivate user');
    }
  };

  const filteredUsers = users.filter(user => {
    const matchesSearch = 
      user.username.toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesRole = roleFilter === 'all' || user.role === roleFilter;

    return matchesSearch && matchesRole;
  });

  if (isLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6"></div>
          <div className="space-y-4">
            {[...Array(5)].map((_, i) => (
              <div key={i} className="h-16 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-gray-900">Manage Users</h1>
        <Button
          onClick={() => setShowAddModal(true)}
          leftIcon={<UserPlus className="h-5 w-5" />}
        >
          Add User
        </Button>
      </div>

      <Card className="mb-6">
        <CardContent className="p-6">
          <div className="flex flex-col md:flex-row gap-4">
            <Input
              placeholder="Search users..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              leftIcon={<Search className="h-5 w-5" />}
              className="flex-grow"
            />
            <Select
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value)}
              options={[
                { value: 'all', label: 'All Roles' },
                { value: 'customer', label: 'Customers' },
                { value: 'agent', label: 'Agents' },
                { value: 'admin', label: 'Admins' }
              ]}
              className="w-full md:w-48"
            />
          </div>
        </CardContent>
      </Card>

      <div className="space-y-4">
        {filteredUsers.map((user) => (
          <Card key={user.id}>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <div className="w-10 h-10 bg-gray-100 rounded-full flex items-center justify-center">
                    <User className="h-5 w-5 text-gray-600" />
                  </div>
                  <div className="ml-4">
                    <h3 className="font-medium text-gray-900">{user.username}</h3>
                    <p className="text-sm text-gray-500">{formatDate(user.created_at)}</p>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <Badge
                    variant={user.role === 'inactive' ? 'danger' : 'success'}
                    className="capitalize"
                  >
                    {user.role === 'inactive' ? 'Inactive' : 'Active'}
                  </Badge>
                  <Select
                    value={user.role}
                    onChange={(e) => handleUpdateRole(user.id, e.target.value)}
                    options={[
                      { value: 'customer', label: 'Customer' },
                      { value: 'agent', label: 'Agent' },
                      { value: 'admin', label: 'Admin' }
                    ]}
                    className="w-32"
                  />
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleDeleteUser(user.id)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Add User Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <Card className="w-full max-w-md">
            <CardHeader>
              <CardTitle>Add New User</CardTitle>
            </CardHeader>
            <CardContent className="p-6">
              <div className="space-y-4">
                <Input
                  label="Email"
                  type="email"
                  value={newUserData.email}
                  onChange={(e) => setNewUserData({ ...newUserData, email: e.target.value })}
                />
                <Input
                  label="Username"
                  value={newUserData.username}
                  onChange={(e) => setNewUserData({ ...newUserData, username: e.target.value })}
                />
                <Input
                  label="Password"
                  type="password"
                  value={newUserData.password}
                  onChange={(e) => setNewUserData({ ...newUserData, password: e.target.value })}
                />
                <Select
                  label="Role"
                  value={newUserData.role}
                  onChange={(e) => setNewUserData({ ...newUserData, role: e.target.value })}
                  options={[
                    { value: 'customer', label: 'Customer' },
                    { value: 'agent', label: 'Agent' },
                    { value: 'admin', label: 'Admin' }
                  ]}
                />
                <div className="flex justify-end gap-2 mt-6">
                  <Button
                    variant="outline"
                    onClick={() => setShowAddModal(false)}
                  >
                    Cancel
                  </Button>
                  <Button onClick={handleAddUser}>
                    Add User
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

export default AdminUsersPage;