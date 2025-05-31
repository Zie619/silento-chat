#!/usr/bin/env python3
"""
Script to update Info.plist for SwiftUI app lifecycle
Removes UIApplicationSceneManifest which is not needed for SwiftUI apps
"""

import plistlib
import sys
import os

def update_info_plist():
    plist_path = "Silento/Info.plist"
    
    if not os.path.exists(plist_path):
        print(f"Error: {plist_path} not found")
        return False
    
    try:
        # Read the plist
        with open(plist_path, 'rb') as f:
            plist_data = plistlib.load(f)
        
        # Remove UIApplicationSceneManifest if it exists
        if 'UIApplicationSceneManifest' in plist_data:
            del plist_data['UIApplicationSceneManifest']
            print("✅ Removed UIApplicationSceneManifest")
        else:
            print("ℹ️  UIApplicationSceneManifest not found (already removed)")
        
        # Write back the plist
        with open(plist_path, 'wb') as f:
            plistlib.dump(plist_data, f)
        
        print(f"✅ Successfully updated {plist_path}")
        return True
        
    except Exception as e:
        print(f"❌ Error updating plist: {e}")
        return False

if __name__ == "__main__":
    print("🔧 Updating Info.plist for SwiftUI...")
    success = update_info_plist()
    sys.exit(0 if success else 1) 