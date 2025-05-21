import React from 'react';

function AddressesPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-6">My Addresses</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Default Address Card */}
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex justify-between items-start mb-4">
            <div>
              <span className="inline-block bg-blue-100 text-blue-800 text-xs font-semibold px-2.5 py-0.5 rounded">Default</span>
              <h3 className="text-lg font-semibold mt-2">Home Address</h3>
            </div>
            <div className="flex gap-2">
              <button className="text-gray-600 hover:text-gray-900">Edit</button>
              <button className="text-red-600 hover:text-red-900">Delete</button>
            </div>
          </div>
          <div className="space-y-1 text-gray-600">
            <p>123 Main Street</p>
            <p>Apt 4B</p>
            <p>New York, NY 10001</p>
            <p>United States</p>
            <p className="mt-2">Phone: (555) 123-4567</p>
          </div>
        </div>

        {/* Add New Address Card */}
        <div className="border-2 border-dashed border-gray-300 rounded-lg p-6 flex items-center justify-center">
          <button className="text-gray-600 hover:text-gray-900 flex flex-col items-center">
            <span className="text-4xl mb-2">+</span>
            <span className="font-medium">Add New Address</span>
          </button>
        </div>
      </div>
    </div>
  );
}

export default AddressesPage;