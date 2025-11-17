# 🏗️ Environment Setup Guide

This guide will help you set up production and development environments for your PodWeb app.

## 📋 What You Need To Do

### 1. 🔥 Create Production Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a project" 
3. Name it `podweb-production`
4. Add iOS app with bundle ID: `com.yourcompany.podweb`
5. Download `GoogleService-Info.plist` 
6. Rename it to `GoogleService-Info-Production.plist`
7. Add it to your Xcode project

### 2. 🔥 Create Development Firebase Project

1. Create another project: `podweb-dev`  
2. Add iOS app with bundle ID: `com.yourcompany.podweb.dev`
3. Download `GoogleService-Info.plist`
4. Rename it to `GoogleService-Info-Development.plist`
5. Add it to your Xcode project

### 3. ☁️ Create Production Cloudflare R2 Bucket

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Navigate to R2 Object Storage
3. Create new bucket: `podweb-production`
4. Create R2 API Token:
   - Click "Manage R2 API Tokens"
   - Click "Create API Token"  
   - Give it permissions for your production bucket
   - Copy the credentials

### 4. 🔧 Update Production Credentials

Edit `/PodWebBlueprint/Service/R2Config.swift` and replace the placeholder values:

```swift
// Replace these with your actual production values:
private static let productionEndpoint = "https://YOUR_ACTUAL_ACCOUNT_ID.r2.cloudflarestorage.com"
private static let productionBucketName = "podweb-production"
private static let productionAccountId = "YOUR_ACTUAL_ACCOUNT_ID"
private static let productionAccessKeyId = "YOUR_ACTUAL_ACCESS_KEY"
private static let productionSecretAccessKey = "YOUR_ACTUAL_SECRET_KEY"
private static let productionPublicDomain = "https://pub-YOUR_ACTUAL_SUBDOMAIN.r2.dev"
```

### 5. 🎯 Set Up Xcode Build Configurations

1. Open your project in Xcode
2. Select project → Info → Configurations
3. Duplicate "Release" → rename to "Production"
4. Duplicate "Debug" → rename to "Development"

### 6. 📱 Create Production Scheme

1. **Product → Scheme → Manage Schemes**
2. Duplicate your current scheme
3. Rename to "PodWebBlueprint-Production"
4. Edit scheme:
   - **Build Configuration**: Set to "Production"
   - **Archive**: Set to "Production"

### 7. 📁 Add Configuration Files to Xcode

1. In Xcode, right-click your project
2. "Add Files to Project"
3. Add both `.xcconfig` files:
   - `Config-Production.xcconfig`
   - `Config-Development.xcconfig`

### 8. 🔗 Link Configurations

1. Project Settings → Info → Configurations
2. Set configurations to use the appropriate `.xcconfig` files:
   - **Production**: `Config-Production.xcconfig`
   - **Development**: `Config-Development.xcconfig`

### 9. 🔄 Add Build Script for Firebase Config Switching

1. Target → Build Phases → "+" → New Run Script Phase
2. Add this script:

```bash
# Copy the appropriate GoogleService-Info.plist for the current configuration
if [ "${CONFIGURATION}" == "Production" ]; then
    cp "${SRCROOT}/PodWebBlueprint/GoogleService-Info-Production.plist" "${SRCROOT}/PodWebBlueprint/GoogleService-Info.plist"
elif [ "${CONFIGURATION}" == "Development" ]; then
    cp "${SRCROOT}/PodWebBlueprint/GoogleService-Info-Development.plist" "${SRCROOT}/PodWebBlueprint/GoogleService-Info.plist"
fi
```

## 🎉 You're Done!

### How to Use:

- **Development**: Use your current scheme (defaults to development environment)
- **Production**: Select "PodWebBlueprint-Production" scheme for production builds

### What This Gives You:

✅ **Separate Firebase Projects**: Production and development data completely isolated  
✅ **Separate R2 Buckets**: Production videos won't mix with test videos  
✅ **Automatic Switching**: Environment automatically detected based on build configuration  
✅ **Easy Deployment**: Switch schemes to build for different environments  

### Environment Indicators:

The app will automatically:
- Use the correct Firebase project
- Use the correct R2 bucket  
- Show different app names ("PodWeb" vs "PodWeb Dev")
- Use appropriate logging levels

## 🔍 Verification

You can verify it's working by checking the console logs:
- Development builds will show debug logs
- Production builds will have minimal logging
- Check which Firebase project is being used in the logs

## 🚨 Security Note

**Never commit your production credentials to version control!** Consider using:
- Environment variables
- Keychain for sensitive data
- CI/CD secrets management

Need help with any step? Let me know! 🚀
