#!/usr/bin/env python3
"""
Script to add Chinese translations to Localizable.xcstrings
This script will add Chinese translations for all English strings
"""

import json
import os

def add_chinese_translations():
    """Add Chinese translations to the Localizable.xcstrings file"""
    
    # Read the current file
    with open('Localizable.xcstrings', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Chinese translations dictionary
    chinese_translations = {
        "Cancel": "取消",
        "Done": "完成",
        "Upload": "上传",
        "Loading...": "加载中...",
        "Log Out": "退出登录",
        "Sign Up": "注册",
        "Sign In": "登录",
        "Continue": "继续",
        "Save": "保存",
        "Delete": "删除",
        "Edit": "编辑",
        "Add": "添加",
        "Create": "创建",
        "Skip": "跳过",
        "OK": "确定",
        "Report": "举报",
        "Copy": "复制",
        "Crop": "裁剪",
        "Follow": "关注",
        "Unfollow": "取消关注",
        "Reply": "回复",
        "Submit": "提交",
        "Send": "发送",
        "Remove": "移除",
        "Change": "更改",
        "Update": "更新",
        "Reset": "重置",
        "Select": "选择",
        "Search...": "搜索...",
        "Link": "链接",
        "Name": "姓名",
        "Bio": "个人简介",
        "Username": "用户名",
        "Password": "密码",
        "Email": "邮箱",
        "+ Photo": "+ 照片",
        "Add a thumbnail": "添加缩略图",
        "Add Media": "添加媒体",
        "Select Media": "选择媒体",
        "From Camera Roll": "从相册",
        "From Files": "从文件",
        "No image selected": "未选择图片",
        "Uploading...": "上传中...",
        "Submitting...": "提交中...",
        "Loading media...": "加载媒体中...",
        "Loading messages...": "加载消息中...",
        "Failed to load media": "加载媒体失败",
        "No more posts to load": "没有更多内容",
        "No pods to show": "没有可显示的播客",
        "No pods yet": "还没有播客",
        "No comments yet": "还没有评论",
        "No replies yet": "还没有回复",
        "No messages yet": "还没有消息",
        "No conversations yet": "还没有对话",
        "No conversations found": "未找到对话",
        "No notifications yet": "还没有通知",
        "Sorry there are no users matching your search.": "抱歉，没有找到匹配的用户。",
        "Sorry there are no pods matching your search.": "抱歉，没有找到匹配的播客。",
        "Be the first to comment!": "成为第一个评论的人！",
        "Be the first to reply!": "成为第一个回复的人！",
        "Add a bio to your profile": "为您的个人资料添加简介",
        "Add a Profile Photo!": "添加个人头像！",
        "Upload your first pod to get started": "上传您的第一个播客开始使用",
        "Follow some users to see their pods here": "关注一些用户以在此处查看他们的播客",
        "Once you have friends, your conversations will appear here": "一旦您有了朋友，您的对话将在此处显示",
        "When you get notifications, they'll show up here": "当您收到通知时，它们将在此处显示",
        "Try searching for a different name": "尝试搜索不同的名称",
        "This user hasn't uploaded any pods yet": "此用户还没有上传任何播客",
        "No thanks, I'll add one later": "不用了，我稍后再添加",
        "Start a conversation with %@!": "与%@开始对话！",
        "Tell us about yourself": "告诉我们关于您自己",
        "Let others know who you are": "让别人知道您是谁",
        "Help us understand what's happening": "帮助我们了解发生了什么",
        "Please provide any additional context...": "请提供任何额外的上下文...",
        "Additional Details": "附加详情",
        "Additional Resources": "附加资源",
        "Frequently Asked Questions": "常见问题",
        "We're here to help you get the most out of your podcasting experience.": "我们在这里帮助您充分利用播客体验。",
        "Would you like to send an email confirmation to our support team?": "您是否要向我们的支持团队发送电子邮件确认？",
        "Send Email Confirmation": "发送电子邮件确认",
        "Password reset email sent successfully": "密码重置邮件发送成功",
        "Password updated successfully": "密码更新成功",
        "Incorrect Password": "密码错误",
        "Already have an account?": "已有账户？",
        "Don't have an account?": "没有账户？",
        "Reset your password.": "重置您的密码。",
        "Send Password Reset Email": "发送密码重置邮件",
        "Update Password": "更新密码",
        "Change Password": "更改密码",
        "New Comment": "新评论",
        "New Reply...": "新回复...",
        "New Message": "新消息",
        "Recent Searches": "最近搜索",
        "Recommended": "推荐",
        "Verified": "已验证",
        "read more": "阅读更多",
        "read less": "收起",
        "Start Time": "开始时间",
        "End Time": "结束时间",
        "Section": "部分",
        "Support": "支持",
        "Attuned": "Attuned",
        "by @%@": "作者：@%@",
        "sent a pod": "发送了一个播客",
        "sent a pod by **%@**": "发送了一个由**%@**制作的播客",
        "Pod no longer available": "播客不再可用",
        "Change playlist name": "更改播放列表名称",
        "Edit playlist name": "编辑播放列表名称",
        "Create a playlist": "创建播放列表",
        "Add to playlist": "添加到播放列表",
        "Remove from playlist": "从播放列表移除",
        "Add pods to your playlist": "将播客添加到您的播放列表",
        "Delete playlist": "删除播放列表",
        "Playlist by: ": "播放列表作者：",
        "Playlist Name": "播放列表名称",
        "Are you sure you want to delete this comment? This action cannot be undone.": "您确定要删除此评论吗？此操作无法撤销。",
        "Are you sure you want to delete this reply? This action cannot be undone.": "您确定要删除此回复吗？此操作无法撤销。",
        "Delete Comment": "删除评论",
        "Delete Reply": "删除回复",
        "Comment Options": "评论选项",
        "Reply Options": "回复选项",
        "Why are you reporting this comment?": "您为什么要举报此评论？",
        "Why are you reporting this user?": "您为什么要举报此用户？",
        "Reason for reporting": "举报原因",
        "Select a reason": "选择原因",
        "Comment being reported:": "被举报的评论：",
        "Pod being reported:": "被举报的播客：",
        "Report Pod": "举报播客",
        "Delete Pod": "删除播客",
        "Notifications": "通知",
        "No notifications yet": "还没有通知",
        "When you get notifications, they'll show up here": "当您收到通知时，它们将在此处显示",
        "Upload Pod": "上传播客",
        "Language": "语言",
        "Select your preferred language": "选择您偏好的语言",
        "Language Updated": "语言已更新",
        "Language updated to %@. Restart the app to see changes.": "语言已更新为%@。重启应用以查看更改。",
        "Terms of Service": "服务条款",
        "Privacy Policy": "隐私政策",
        "Terms & Policies": "条款和政策",
        "Terms and Policies": "条款和政策",
        "1. Acceptance of Terms": "1. 接受条款",
        "By accessing and using Attuned, you agree to be bound by these Terms of Service and all applicable laws and regulations.": "通过访问和使用Attuned，您同意受这些服务条款和所有适用法律法规的约束。",
        "2. User Accounts": "2. 用户账户",
        "You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.": "您负责维护账户信息的机密性以及账户下发生的所有活动。",
        "3. Content Guidelines": "3. 内容指南",
        "Users must not post content that is illegal, harmful, threatening, abusive, harassing, defamatory, or otherwise objectionable.": "用户不得发布非法、有害、威胁、辱骂、骚扰、诽谤或其他令人反感的内容。",
        "4. Intellectual Property": "4. 知识产权",
        "All content and materials available on Attuned are protected by intellectual property rights and may not be used without permission.": "Attuned上提供的所有内容和材料均受知识产权保护，未经许可不得使用。",
        "5. Termination": "5. 终止",
        "We reserve the right to terminate or suspend your account at any time for violations of these terms.": "我们保留随时因违反这些条款而终止或暂停您账户的权利。",
        "1. Information We Collect": "1. 我们收集的信息",
        "We collect information you provide directly to us, including your name, email address, and profile information.": "我们收集您直接提供给我们的信息，包括您的姓名、电子邮件地址和个人资料信息。",
        "2. How We Use Your Information": "2. 我们如何使用您的信息",
        "We use your information to provide, maintain, and improve our services, communicate with you, and ensure platform security.": "我们使用您的信息来提供、维护和改进我们的服务，与您沟通，并确保平台安全。",
        "3. Information Sharing": "3. 信息共享",
        "We do not sell your personal information. We may share information with service providers who assist in operating our platform.": "我们不出售您的个人信息。我们可能与协助运营我们平台的服务提供商共享信息。",
        "4. Data Security": "4. 数据安全",
        "We implement appropriate security measures to protect your personal information from unauthorized access.": "我们实施适当的安全措施来保护您的个人信息免受未经授权的访问。",
        "5. Your Rights": "5. 您的权利",
        "You have the right to access, correct, or delete your personal information. Contact us to exercise these rights.": "您有权访问、更正或删除您的个人信息。请联系我们行使这些权利。",
        "6. Changes to This Policy": "6. 本政策的变更",
        "We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy on this page.": "我们可能会不时更新此隐私政策。我们将通过在此页面上发布新政策来通知您任何变更。",
        "Last Updated: March 2024": "最后更新：2024年3月",
        "Spam": "垃圾信息",
        "Inappropriate Content": "不当内容",
        "Harassment": "骚扰",
        "False Information": "虚假信息",
        "Impersonation": "冒充",
        "Unwanted commercial content or repetitive posts": "不需要的商业内容或重复帖子",
        "Content that violates community guidelines": "违反社区指南的内容",
        "Bullying, threats, or abusive behavior": "欺凌、威胁或辱骂行为",
        "Misleading or factually incorrect information": "误导性或事实错误的信息",
        "Other reasons not listed above": "上述未列出的其他原因",
        "Someone pretending to be another person": "冒充他人的人",
        "How do I create a podcast?": "如何创建播客？",
        "How do I follow other users?": "如何关注其他用户？",
        "How do I manage my privacy settings?": "如何管理我的隐私设置？",
        "How do I report inappropriate content?": "如何举报不当内容？",
        "How do I change my profile picture?": "如何更改我的头像？",
        "To create a podcast, tap the '+' button in the main feed, select 'Create Podcast', and follow the setup wizard. You'll need to provide a title, description, and upload your audio file.": "要创建播客，请点击主信息流中的'+'按钮，选择'创建播客'，然后按照设置向导操作。您需要提供标题、描述并上传音频文件。",
        "You can follow other users by visiting their profile and tapping the 'Follow' button. You'll then see their content in your feed.": "您可以通过访问他们的个人资料并点击'关注'按钮来关注其他用户。然后您将在信息流中看到他们的内容。",
        "Go to Settings > Account Privacy to manage your privacy settings. You can make your account private, control who can see your content, and manage your followers.": "转到设置 > 账户隐私来管理您的隐私设置。您可以使账户私密，控制谁可以看到您的内容，并管理您的关注者。",
        "Tap the three dots menu on any post or comment and select 'Report'. Our team will review the content and take appropriate action.": "点击任何帖子或评论上的三点菜单并选择'举报'。我们的团队将审查内容并采取适当行动。",
        "Go to your profile, tap your profile picture, and select 'Change Photo'. You can choose from your photo library or take a new photo.": "转到您的个人资料，点击您的头像，然后选择'更改照片'。您可以从照片库中选择或拍摄新照片。",
        "This Account is Private": "此账户为私密账户",
        "When your account is private, only your friends can see your profile and activity.": "当您的账户为私密时，只有您的朋友可以看到您的个人资料和活动。",
        "Switch between light and dark mode for the app.": "在应用的光模式和暗模式之间切换。",
        "You must be mutual friends to see their content": "必须是互相关注的朋友才能查看内容"
    }
    
    # Add Chinese translations to all strings
    for key, value in data['strings'].items():
        if key and not key.startswith('%') and not key.startswith('@') and key in chinese_translations:
            if 'localizations' not in value:
                value['localizations'] = {}
            
            # Add Chinese translation
            value['localizations']['zh'] = {
                'stringUnit': {
                    'state': 'translated',
                    'value': chinese_translations[key]
                }
            }
    
    # Write back to file
    with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print("✅ Added Chinese translations to Localizable.xcstrings")
    print(f"📝 Added {len(chinese_translations)} Chinese translations")
    print("🔧 Chinese language support is now available in your app")

if __name__ == "__main__":
    if not os.path.exists('Localizable.xcstrings'):
        print("❌ Localizable.xcstrings file not found in current directory")
        exit(1)
    
    add_chinese_translations() 