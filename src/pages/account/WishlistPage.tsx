import React from 'react';

function WishlistPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-6">My Wishlist</h1>
      <div className="bg-white rounded-lg shadow p-6">
        <p className="text-gray-600">Your wishlist is currently empty.</p>
      </div>
    </div>
  );
}

export default WishlistPage;