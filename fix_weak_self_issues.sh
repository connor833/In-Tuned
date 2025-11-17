#!/bin/bash

# Fix Weak Self Issues Script
# This script helps identify and fix 'self is immutable' errors in Swift closures

echo "🔍 Finding weak self issues throughout the codebase..."

# Find all Swift files with weak self issues
echo "📁 Searching for files with weak self issues..."

# Pattern 1: self?.property assignments
echo "1️⃣ Finding self?.property assignments..."
grep -r "self\?\." --include="*.swift" . | head -20

echo ""
echo "2️⃣ Finding self?[subscript] assignments..."
grep -r "self\?\[" --include="*.swift" . | head -20

echo ""
echo "3️⃣ Finding closures with [weak self] but no guard let self..."
grep -r "\[weak self\]" --include="*.swift" . | head -20

echo ""
echo "📋 Summary of files that need fixing:"
echo "======================================"

# Get unique files with issues
echo "Files with self?.property assignments:"
grep -r "self\?\." --include="*.swift" . | cut -d: -f1 | sort | uniq | head -10

echo ""
echo "Files with self?[subscript] assignments:"
grep -r "self\?\[" --include="*.swift" . | cut -d: -f1 | sort | uniq | head -10

echo ""
echo "🔧 To fix these issues, you need to:"
echo "1. Add [weak self] to closure parameters"
echo "2. Add guard let self = self else { return } at the start of closures"
echo "3. Replace self?.property with self.property"
echo "4. Replace self?[key] with self[key]"
echo ""
echo "💡 Example fix:"
echo "Before:"
echo "  completion: { [weak self] in"
echo "    self?.property = value"
echo "  }"
echo ""
echo "After:"
echo "  completion: { [weak self] in"
echo "    guard let self = self else { return }"
echo "    self.property = value"
echo "  }"
echo ""
echo "🚀 Run this script again after fixing to verify all issues are resolved!"
