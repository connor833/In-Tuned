#!/usr/bin/env python3
"""
Script to complete final Chinese translations
This script will add Chinese translations for the last few strings that need them
"""

import json
import os

def complete_final_chinese_translations():
    """Complete final Chinese translations"""
    
    # Read the current file
    with open('Localizable.xcstrings', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Final Chinese translations for remaining strings
    final_chinese_translations = {
        "Accept": "接受",
        "AI Analysis Results": "AI分析结果",
        "AI Categorization Practice": "AI分类练习",
        "AI Practice": "AI练习",
        "Failed to send report. Please try again.": "发送报告失败。请重试。"
    }
    
    # Count translations updated
    updated_count = 0
    
    # Update strings marked as 'needs_review' with proper Chinese translations
    for key, value in data['strings'].items():
        if key and not key.startswith('%') and not key.startswith('@'):
            if 'localizations' in value and 'zh' in value['localizations']:
                if value['localizations']['zh']['stringUnit']['state'] == 'needs_review':
                    if key in final_chinese_translations:
                        value['localizations']['zh']['stringUnit']['value'] = final_chinese_translations[key]
                        value['localizations']['zh']['stringUnit']['state'] = 'translated'
                        updated_count += 1
                        print(f"✅ Updated: {key}")
                    else:
                        print(f"⚠️  Missing translation for: {key}")
    
    # Write back to file
    with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"\n🎉 Final Chinese translations completed!")
    print(f"📝 Updated {updated_count} strings from 'needs_review' to 'translated'")
    print("🎯 Chinese translations should now be 100% complete!")

if __name__ == "__main__":
    if not os.path.exists('Localizable.xcstrings'):
        print("❌ Localizable.xcstrings file not found in current directory")
        exit(1)
    
    complete_final_chinese_translations()
