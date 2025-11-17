#!/usr/bin/env python3
"""
Script to finalize Chinese translations for remaining strings
This script will add Chinese translations for strings that don't have any localizations
"""

import json
import os

def finalize_chinese_translations():
    """Finalize Chinese translations for remaining strings"""
    
    # Read the current file
    with open('Localizable.xcstrings', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Additional Chinese translations for remaining strings
    additional_chinese_translations = {
        "%@ reposted": "%@ 转发了",
        "%@'s pod": "%@的播客",
        "by %@": "作者：%@",
        "Loading conversations...": "加载对话中...",
        "No conversations match your search": "没有对话匹配您的搜索",
        "No Follow Requests": "没有关注请求",
        "No playlists yet": "还没有播放列表",
        "No pods found": "未找到播客",
        "No pods in playlist": "播放列表中没有播客",
        "No reposts yet": "还没有转发",
        "No saved pods yet": "还没有保存的播客",
        "Playlists": "播放列表",
        "Pod not available": "播客不可用",
        "Pod shared": "播客已分享",
        "Repost": "转发",
        "Repost pods you love to share with your followers": "转发您喜欢的播客与关注者分享",
        "Reposting:": "转发中：",
        "Save pods you like to find them later": "保存您喜欢的播客以便稍后查找",
        "Saved Pods": "已保存的播客",
        "Start a conversation with someone new": "与新朋友开始对话",
        "Start conversations with friends to share pods!": "与朋友开始对话分享播客！",
        "This user hasn't created any playlists yet": "此用户还没有创建任何播放列表",
        "This user hasn't reposted any pods yet": "此用户还没有转发任何播客",
        "Try searching for a different title": "尝试搜索不同的标题",
        "Unrepost": "取消转发",
        "When people request to follow you, they'll appear here": "当人们请求关注您时，他们会出现在这里",
        "You must follow this user to see their content": "您必须关注此用户才能查看其内容"
    }
    
    # Count translations added
    added_count = 0
    
    # Add Chinese translations to strings that don't have any localizations
    for key, value in data['strings'].items():
        if key and not key.startswith('%') and not key.startswith('@'):
            if 'localizations' not in value or not value['localizations']:
                # This string has no localizations at all
                if key in additional_chinese_translations:
                    value['localizations'] = {
                        'zh': {
                            'stringUnit': {
                                'state': 'translated',
                                'value': additional_chinese_translations[key]
                            }
                        }
                    }
                    added_count += 1
                    print(f"✅ Added Chinese translation for: {key}")
                else:
                    print(f"⚠️  Missing Chinese translation for: {key}")
    
    # Write back to file
    with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"\n🎉 Chinese translations finalized!")
    print(f"📝 Added {added_count} additional Chinese translations")
    print("🔍 Check the file for any remaining strings that need manual translation")

if __name__ == "__main__":
    if not os.path.exists('Localizable.xcstrings'):
        print("❌ Localizable.xcstrings file not found in current directory")
        exit(1)
    
    finalize_chinese_translations()
