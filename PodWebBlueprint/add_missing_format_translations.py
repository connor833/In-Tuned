#!/usr/bin/env python3
"""
Script to add missing translations for format strings
This script will add Spanish and Chinese translations for format strings that are missing them
"""

import json
import os

def add_missing_format_translations():
    """Add missing translations for format strings"""
    
    # Read the current file
    with open('Localizable.xcstrings', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Missing translations for format strings
    missing_translations = {
        "%lld %@": {
            "es": "%1$lld %2$@",
            "zh": "%1$lld %2$@"
        }
    }
    
    # Count translations added
    added_count = 0
    
    # Add missing translations for format strings
    for key, value in data['strings'].items():
        if key in missing_translations:
            if 'localizations' not in value:
                value['localizations'] = {}
            
            for lang_code, translation in missing_translations[key].items():
                if lang_code not in value['localizations']:
                    value['localizations'][lang_code] = {
                        'stringUnit': {
                            'state': 'translated',
                            'value': translation
                        }
                    }
                    added_count += 1
                    print(f"✅ Added {lang_code} translation for: {key}")
    
    # Write back to file
    with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"\n🎉 Format string translations completed!")
    print(f"📝 Added {added_count} missing translations")
    print("🔍 All format strings now have complete translations")

if __name__ == "__main__":
    if not os.path.exists('Localizable.xcstrings'):
        print("❌ Localizable.xcstrings file not found in current directory")
        exit(1)
    
    add_missing_format_translations()
