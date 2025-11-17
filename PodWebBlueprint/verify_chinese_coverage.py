#!/usr/bin/env python3
"""
Script to verify Chinese translation coverage
This script will count and analyze Chinese translations in Localizable.xcstrings
"""

import json
import os

def verify_chinese_coverage():
    """Verify Chinese translation coverage"""
    
    # Read the current file
    with open('Localizable.xcstrings', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Counters
    total_strings = 0
    chinese_translated = 0
    chinese_needs_review = 0
    chinese_missing = 0
    
    # Analyze each string
    for key, value in data['strings'].items():
        if key and not key.startswith('%') and not key.startswith('@'):
            total_strings += 1
            
            if 'localizations' in value and 'zh' in value['localizations']:
                state = value['localizations']['zh']['stringUnit']['state']
                if state == 'translated':
                    chinese_translated += 1
                elif state == 'needs_review':
                    chinese_needs_review += 1
                else:
                    chinese_needs_review += 1
            else:
                chinese_missing += 1
    
    # Calculate percentages
    total_translatable = chinese_translated + chinese_needs_review + chinese_missing
    coverage_percentage = (chinese_translated / total_translatable * 100) if total_translatable > 0 else 0
    
    # Print results
    print("🔍 Chinese Translation Coverage Analysis")
    print("=" * 50)
    print(f"📊 Total translatable strings: {total_translatable}")
    print(f"✅ Chinese translations (translated): {chinese_translated}")
    print(f"⚠️  Chinese translations (needs_review): {chinese_needs_review}")
    print(f"❌ Chinese translations (missing): {chinese_missing}")
    print(f"📈 Coverage: {coverage_percentage:.1f}%")
    
    if coverage_percentage == 100:
        print("\n🎉 Perfect! Chinese translations are 100% complete!")
    elif coverage_percentage >= 95:
        print(f"\n🌟 Excellent! Chinese translations are {coverage_percentage:.1f}% complete!")
    elif coverage_percentage >= 90:
        print(f"\n👍 Good! Chinese translations are {coverage_percentage:.1f}% complete!")
    else:
        print(f"\n🔧 Chinese translations need more work. Current coverage: {coverage_percentage:.1f}%")
    
    # Show strings that need attention
    if chinese_needs_review > 0 or chinese_missing > 0:
        print(f"\n📝 Strings needing attention:")
        for key, value in data['strings'].items():
            if key and not key.startswith('%') and not key.startswith('@'):
                if 'localizations' not in value or 'zh' not in value['localizations']:
                    print(f"  ❌ Missing: {key}")
                elif value['localizations']['zh']['stringUnit']['state'] != 'translated':
                    print(f"  ⚠️  Needs review: {key}")

if __name__ == "__main__":
    if not os.path.exists('Localizable.xcstrings'):
        print("❌ Localizable.xcstrings file not found in current directory")
        exit(1)
    
    verify_chinese_coverage()
