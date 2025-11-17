#!/usr/bin/env python3
"""
Script to complete Chinese translations for Localizable.xcstrings
This script will add Chinese translations for all strings that don't have them
"""

import json
import os

def complete_chinese_translations():
    """Complete Chinese translations for all strings"""
    
    # Read the current file
    with open('Localizable.xcstrings', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Chinese translations dictionary - comprehensive coverage
    chinese_translations = {
        # Missing translations from the file
        "%@ reposted": "%@ 转发了",
        "%@'s pod": "%@的播客",
        "• Change your privacy settings": "• 更改您的隐私设置",
        "• Delete Account: Permanently remove your account and all data": "• 删除账户：永久删除您的账户和所有数据",
        "• Delete specific content instead": "• 改为删除特定内容",
        "• Download Account Data: Get a copy of all your personal data": "• 下载账户数据：获取您所有个人数据的副本",
        "• Temporarily disable your account": "• 暂时禁用您的账户",
        "0 likes": "0个赞",
        "1. Acceptance of Terms": "1. 接受条款",
        "2. How We Use Your Information": "2. 我们如何使用您的信息",
        "3. Information Sharing": "3. 信息共享",
        "4. Data Security": "4. 数据安全",
        "5. Your Rights": "5. 您的权利",
        "6. Changes to This Policy": "6. 本政策的变更",
        "About Account Actions": "关于账户操作",
        "Account Actions": "账户操作",
        "Account Deleted": "账户已删除",
        "Account Information": "账户信息",
        "Account Settings": "账户设置",
        "Add a caption (optional)": "添加说明（可选）",
        "Add a tag...": "添加标签...",
        "Add some pods to this playlist first": "请先在此播放列表中添加一些播客",
        "Add tags...": "添加标签...",
        "All Keywords in '%@' Category": "'%@' 类别中的所有关键词",
        "All your pods will be permanently deleted": "您的所有播客将被永久删除",
        "Are you sure you want to delete this conversation? This action cannot be undone.": "您确定要删除此对话吗？此操作无法撤销。",
        "Are You Sure?": "您确定吗？",
        "Available": "可用",
        "Business": "商业",
        "by %@": "作者：%@",
        "By accessing and using Attuned, you agree to be bound by these Terms of Service and all applicable laws and regulations.": "通过访问和使用Attuned，您同意受这些服务条款和所有适用法律法规的约束。",
        "Category": "类别",
        "Change": "更改",
        "Clear": "清除",
        "Comedy": "喜剧",
        "Comment being reported:": "被举报的评论：",
        "Consider these alternatives:": "考虑这些替代方案：",
        "Content Issue": "内容问题",
        "Content Recommendations": "内容推荐",
        "Content that violates community guidelines": "违反社区指南的内容",
        "Create Playlist": "创建播放列表",
        "Create your first playlist to get started": "创建您的第一个播放列表开始使用",
        "Delete Account": "删除账户",
        "Delete Conversation": "删除对话",
        "Delete My Account": "删除我的账户",
        "Deleting your account is a permanent action that cannot be undone.": "删除您的账户是一个无法撤销的永久操作。",
        "Description": "描述",
        "Display": "显示",
        "Document": "文档",
        "Download": "下载",
        "Download Account Data": "下载账户数据",
        "Download Completed": "下载完成",
        "Download Error": "下载错误",
        "Education": "教育",
        "Enter pod description...": "输入播客描述...",
        "Enter pod title...": "输入播客标题...",
        "Error": "错误",
        "Feature Request": "功能请求",
        "Final Confirmation": "最终确认",
        "Follow Requests": "关注请求",
        "Keyword Scoring (Debug)": "关键词评分（调试）",
        "Last Data Download": "最后数据下载",
        "Last Updated: March 2024": "最后更新：2024年3月",
        "Loading conversations...": "加载对话中...",
        "Mail is not configured on this device. Please contact support directly at %@": "此设备未配置邮箱。请直接联系支持团队：%@",
        "Member Since": "注册时间",
        "Music": "音乐",
        "New playlist": "新播放列表",
        "New pod": "新播客",
        "No content to show": "没有内容可显示",
        "No conversations match your search": "没有对话匹配您的搜索",
        "No Follow Requests": "没有关注请求",
        "No playlists yet": "还没有播放列表",
        "No pods found": "未找到播客",
        "No pods in playlist": "播放列表中没有播客",
        "No reposts yet": "还没有转发",
        "No saved pods yet": "还没有保存的播客",
        "Other": "其他",
        "Other reasons not listed above": "上述未列出的其他原因",
        "Password": "密码",
        "Playlists": "播放列表",
        "Pod not available": "播客不可用",
        "Pod shared": "播客已分享",
        "Please provide any additional details about the issue you're experiencing.": "请提供您遇到的问题的任何其他详细信息。",
        "Processing...": "处理中...",
        "read less": "收起",
        "read more": "阅读更多",
        "Reject": "拒绝",
        "Remove pods from playlist": "从播放列表中移除播客",
        "Report a Problem": "报告问题",
        "Report cancelled.": "报告已取消。",
        "Report Comment": "举报评论",
        "Report Pod": "举报播客",
        "Report saved successfully! Since mail is not configured on this device, please contact support directly at %@": "报告保存成功！由于此设备未配置邮箱，请直接联系支持团队：%@",
        "Report saved to drafts.": "报告已保存到草稿。",
        "Report sent successfully! We'll get back to you soon.": "报告发送成功！我们会很快回复您。",
        "Report Status": "报告状态",
        "Report Submitted": "报告已提交",
        "Report User": "举报用户",
        "Repost": "转发",
        "Repost pods you love to share with your followers": "转发您喜欢的播客与关注者分享",
        "Reposting:": "转发中：",
        "Reset": "重置",
        "Save pods you like to find them later": "保存您喜欢的播客以便稍后查找",
        "Saved Pods": "已保存的播客",
        "Science": "科学",
        "Selected Keywords": "选定的关键词",
        "Someone pretending to be another person": "冒充他人的人",
        "Start a conversation with someone new": "与新朋友开始对话",
        "Start conversations with friends to share pods!": "与朋友开始对话分享播客！",
        "Submit Report": "提交报告",
        "Tags": "标签",
        "Tags (Optional)": "标签（可选）",
        "Test AI Categorization": "测试AI分类",
        "Test how the AI categorizes your content": "测试AI如何对您的内容进行分类",
        "This action is IRREVERSIBLE and CANNOT be undone. Your account, pods, and personal data will be permanently deleted. Are you absolutely certain you want to proceed?": "此操作不可逆转且无法撤销。您的账户、播客和个人数据将被永久删除。您绝对确定要继续吗？",
        "This action will permanently delete your account and all associated data.": "此操作将永久删除您的账户和所有相关数据。",
        "This user hasn't created any playlists yet": "此用户还没有创建任何播放列表",
        "This user hasn't reposted any pods yet": "此用户还没有转发任何播客",
        "This will prepare a copy of all your account data including profile information, pods, comments, and preferences. The download will be available shortly.": "这将准备您所有账户数据的副本，包括个人资料信息、播客、评论和偏好设置。下载将很快可用。",
        "Title": "标题",
        "Try Again": "重试",
        "Try searching for a different title": "尝试搜索不同的标题",
        "Unrepost": "取消转发",
        "Users must not post content that is illegal, harmful, threatening, abusive, harassing, defamatory, or otherwise objectionable.": "用户不得发布非法、有害、威胁、辱骂、骚扰、诽谤或其他令人反感的内容。",
        "Warning": "警告",
        "We collect information you provide directly to us, including your name, email address, and profile information.": "我们收集您直接提供给我们的信息，包括您的姓名、电子邮件地址和个人资料信息。",
        "We do not sell your personal information. We may share information with service providers who assist in operating our platform.": "我们不出售您的个人信息。我们可能与协助运营我们平台的服务提供商共享信息。",
        "We implement appropriate security measures to protect your personal information from unauthorized access.": "我们实施适当的安全措施来保护您的个人信息免受未经授权的访问。",
        "We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy on this page.": "我们可能会不时更新此隐私政策。我们将通过在此页面上发布新政策来通知您任何变更。",
        "We reserve the right to terminate or suspend your account at any time for violations of these terms.": "我们保留随时因违反这些条款而终止或暂停您账户的权利。",
        "We use your information to provide, maintain, and improve our services, communicate with you, and ensure platform security.": "我们使用您的信息来提供、维护和改进我们的服务，与您沟通，并确保平台安全。",
        "We're here to help you get the most out of your podcasting experience.": "我们在这里帮助您充分利用播客体验。",
        "What do you think about this pod?": "您觉得这个播客怎么样？",
        "What will happen:": "将会发生什么：",
        "When people request to follow you, they'll appear here": "当人们请求关注您时，他们会出现在这里",
        "Yes, Delete Forever": "是的，永久删除",
        "You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.": "您负责维护账户信息的机密性以及账户下发生的所有活动。",
        "You have the right to access, correct, or delete your personal information. Contact us to exercise these rights.": "您有权访问、更正或删除您的个人信息。请联系我们行使这些权利。",
        "You must follow this user to see their content": "您必须关注此用户才能查看其内容",
        "Your account data has been exported and uploaded to Firebase Storage. You can now download the JSON file using the button below, and it will be available for 30 days.": "您的账户数据已导出并上传到Firebase存储。您现在可以使用下面的按钮下载JSON文件，它将可用30天。",
        "Your comments will remain but show as 'Anonymous User'": "您的评论将保留但显示为'匿名用户'",
        "Your email will be freed for future use": "您的邮箱将被释放以供将来使用",
        "Your personal information will be anonymized": "您的个人信息将被匿名化"
    }
    
    # Count missing translations
    missing_count = 0
    added_count = 0
    
    # Add Chinese translations to all strings
    for key, value in data['strings'].items():
        if key and not key.startswith('%') and not key.startswith('@'):
            # Check if this string needs Chinese translation
            if 'localizations' not in value:
                value['localizations'] = {}
                missing_count += 1
            
            if 'zh' not in value['localizations']:
                # Add Chinese translation
                if key in chinese_translations:
                    value['localizations']['zh'] = {
                        'stringUnit': {
                            'state': 'translated',
                            'value': chinese_translations[key]
                        }
                    }
                    added_count += 1
                else:
                    # Use English as placeholder for missing translations
                    value['localizations']['zh'] = {
                        'stringUnit': {
                            'state': 'needs_review',
                            'value': key  # Use English as placeholder
                        }
                    }
                    missing_count += 1
    
    # Write back to file
    with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print("✅ Chinese translations completed!")
    print(f"📝 Added {added_count} proper Chinese translations")
    print(f"⚠️  {missing_count} strings still need manual Chinese translation")
    print("🔧 Check the file for strings marked as 'needs_review' and add proper Chinese translations")

if __name__ == "__main__":
    if not os.path.exists('Localizable.xcstrings'):
        print("❌ Localizable.xcstrings file not found in current directory")
        exit(1)
    
    complete_chinese_translations()
