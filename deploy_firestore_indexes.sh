#!/bin/bash

# Deploy Firestore Indexes
echo "🚀 Deploying Firestore indexes..."

# Check if firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in
if ! firebase auth:list &> /dev/null; then
    echo "🔐 Please login to Firebase first:"
    firebase login
fi

# Deploy indexes
echo "📊 Deploying indexes from firestore.indexes.json..."
firebase deploy --only firestore:indexes

echo "✅ Firestore indexes deployed successfully!"
echo ""
echo "📋 New indexes created:"
echo "   - pods: userId + timestamp (DESC)"
echo ""
echo "⏳ Note: Index creation may take a few minutes to complete."
echo "   You can monitor progress in the Firebase Console."
