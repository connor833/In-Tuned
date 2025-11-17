#!/usr/bin/env python3
"""
Script to add new language support to Localizable.xcstrings
Usage: python3 add_language_support.py <language_code> <language_name>
Example: python3 add_language_support.py fr French
"""

import json
import sys
import os

def add_language_support(language_code, language_name):
    """Add a new language to the Localizable.xcstrings file"""
    
    # Read the current file
    with open('Localizable.xcstrings', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Get all English strings (source language)
    english_strings = {}
    for key, value in data['strings'].items():
        if key and not key.startswith('%') and not key.startswith('@'):
            # This is a translatable string
            english_strings[key] = key  # Use English as the default translation
    
    # Add the new language to all strings
    for key, value in data['strings'].items():
        if key in english_strings:
            if 'localizations' not in value:
                value['localizations'] = {}
            
            # Add the new language with English as placeholder
            value['localizations'][language_code] = {
                'stringUnit': {
                    'state': 'needs_review',
                    'value': english_strings[key]  # Use English as placeholder
                }
            }
    
    # Write back to file
    with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"✅ Added {language_name} ({language_code}) support to Localizable.xcstrings")
    print(f"📝 All strings now have {language_code} entries with English placeholders")
    print(f"🔧 You can now edit the file to add proper {language_name} translations")

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 add_language_support.py <language_code> <language_name>")
        print("Example: python3 add_language_support.py fr French")
        sys.exit(1)
    
    language_code = sys.argv[1]
    language_name = sys.argv[2]
    
    if not os.path.exists('Localizable.xcstrings'):
        print("❌ Localizable.xcstrings file not found in current directory")
        sys.exit(1)
    
    add_language_support(language_code, language_name)

if __name__ == "__main__":
    main() 