import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import MainLayout from './components/layout/MainLayout';
import HomePage from './pages/HomePage';
import ProductsPage from './pages/ProductsPage';
import ProductDetailPage from './pages/ProductDetailPage';
import CartPage from './pages/CartPage';
import CheckoutPage from './pages/CheckoutPage';
import SharedOrderPage from './pages/SharedOrderPage';
import PaymentSuccessPage from './pages/payment/SuccessPage';
import LoginPage from './pages/auth/LoginPage';
import RegisterPage from './pages/auth/RegisterPage';
import ForgotPasswordPage from './pages/auth/ForgotPasswordPage';
import AccountPage from './pages/account/AccountPage';
import OrdersPage from './pages/account/OrdersPage';
import OrderDetailPage from './pages/account/OrderDetailPage';
import AddressesPage from './pages/account/AddressesPage';
import WishlistPage from './pages/account/WishlistPage';
import AgentDashboardPage from './pages/agent/AgentDashboardPage';
import AgentOrdersPage from './pages/agent/AgentOrdersPage';
import AgentTeamPage from './pages/agent/AgentTeamPage';
import AgentEarningsPage from './pages/agent/AgentEarningsPage';
import AdminDashboardPage from './pages/admin/AdminDashboardPage';
import AdminProductsPage from './pages/admin/AdminProductsPage';
import AdminOrdersPage from './pages/admin/AdminOrdersPage';
import PaymentSettingsPage from './pages/admin/PaymentSettingsPage';
import AdminUsersPage from './pages/admin/AdminUsersPage';
import AdminAgentsPage from './pages/admin/AdminAgentsPage';
import ProtectedRoute from './components/auth/ProtectedRoute';

function App() {
  return (
    <Router>
      <Toaster position="top-center" />
      <Routes>
        <Route path="/" element={<MainLayout><HomePage /></MainLayout>} />
        <Route path="/products" element={<MainLayout><ProductsPage /></MainLayout>} />
        <Route path="/products/:id" element={<MainLayout><ProductDetailPage /></MainLayout>} />
        <Route path="/cart" element={<MainLayout><CartPage /></MainLayout>} />
        <Route path="/checkout" element={<MainLayout><CheckoutPage /></MainLayout>} />
        <Route path="/shared-order/:shareId" element={<MainLayout><SharedOrderPage /></MainLayout>} />
        <Route path="/payment/success" element={<MainLayout><PaymentSuccessPage /></MainLayout>} />
        
        {/* Auth routes */}
        <Route path="/login" element={<MainLayout><LoginPage /></MainLayout>} />
        <Route path="/register" element={<MainLayout><RegisterPage /></MainLayout>} />
        <Route path="/forgot-password" element={<MainLayout><ForgotPasswordPage /></MainLayout>} />
        
        {/* Account routes */}
        <Route 
          path="/account" 
          element={
            <ProtectedRoute>
              <MainLayout><AccountPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/orders" 
          element={
            <ProtectedRoute>
              <MainLayout><OrdersPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/orders/:id" 
          element={
            <ProtectedRoute>
              <MainLayout><OrderDetailPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/addresses" 
          element={
            <ProtectedRoute>
              <MainLayout><AddressesPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/wishlist" 
          element={
            <ProtectedRoute>
              <MainLayout><WishlistPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        
        {/* Agent routes */}
        <Route 
          path="/agent-dashboard" 
          element={
            <ProtectedRoute requiredRole="agent">
              <MainLayout><AgentDashboardPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/agent-orders" 
          element={
            <ProtectedRoute requiredRole="agent">
              <MainLayout><AgentOrdersPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/agent-team" 
          element={
            <ProtectedRoute requiredRole="agent">
              <MainLayout><AgentTeamPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/agent-earnings" 
          element={
            <ProtectedRoute requiredRole="agent">
              <MainLayout><AgentEarningsPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        
        {/* Admin routes */}
        <Route 
          path="/admin" 
          element={
            <ProtectedRoute requiredRole="admin">
              <MainLayout><AdminDashboardPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/admin/products" 
          element={
            <ProtectedRoute requiredRole="admin">
              <MainLayout><AdminProductsPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/admin/orders" 
          element={
            <ProtectedRoute requiredRole="admin">
              <MainLayout><AdminOrdersPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/admin/settings/payment" 
          element={
            <ProtectedRoute requiredRole="admin">
              <MainLayout><PaymentSettingsPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/admin/users" 
          element={
            <ProtectedRoute requiredRole="admin">
              <MainLayout><AdminUsersPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
        <Route 
          path="/admin/agents" 
          element={
            <ProtectedRoute requiredRole="admin">
              <MainLayout><AdminAgentsPage /></MainLayout>
            </ProtectedRoute>
          } 
        />
      </Routes>
    </Router>
  );
}

export default App;