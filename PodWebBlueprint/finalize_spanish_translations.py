#!/usr/bin/env python3
"""
Script to finalize Spanish translations for all remaining strings
This script will add proper Spanish translations for strings marked as 'needs_review'
"""

import json
import os

def finalize_spanish_translations():
    """Finalize Spanish translations for all remaining strings"""
    
    # Read the current file
    with open('Localizable.xcstrings', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Comprehensive Spanish translations for remaining strings
    spanish_translations = {
        # UI Elements
        "+ Photo": "+ Foto",
        "1. Information We Collect": "1. Información que Recopilamos",
        "2. User Accounts": "2. Cuentas de Usuario",
        "3. Content Guidelines": "3. Pautas de Contenido",
        "4. Intellectual Property": "4. Propiedad Intelectual",
        "5. Termination": "5. Terminación",
        "Accept": "Aceptar",
        "Account Privacy": "Privacidad de Cuenta",
        "Account Problem": "Problema de Cuenta",
        "Additional Comments (Optional)": "Comentarios Adicionales (Opcional)",
        "Additional details (optional)": "Detalles adicionales (opcional)",
        "Additional Details (Optional)": "Detalles Adicionales (Opcional)",
        "AI Analysis Results": "Resultados del Análisis IA",
        "AI Categorization Practice": "Práctica de Categorización IA",
        "AI Practice": "Práctica IA",
        "All content and materials available on Attuned are protected by intellectual property rights and may not be used without permission.": "Todo el contenido y materiales disponibles en Attuned están protegidos por derechos de propiedad intelectual y no pueden ser utilizados sin permiso.",
        "App Updates": "Actualizaciones de la App",
        "Are you sure you want to delete this conversation? This action cannot be undone.": "¿Estás seguro de que quieres eliminar esta conversación? Esta acción no se puede deshacer.",
        "Available": "Disponible",
        "Business": "Negocios",
        "by %@": "por %@",
        "By accessing and using Attuned, you agree to be bound by these Terms of Service and all applicable laws and regulations.": "Al acceder y usar Attuned, aceptas estar sujeto a estos Términos de Servicio y todas las leyes y regulaciones aplicables.",
        "Category": "Categoría",
        "Change": "Cambiar",
        "Clear": "Limpiar",
        "Comedy": "Comedia",
        "Comment being reported:": "Comentario siendo reportado:",
        "Consider these alternatives:": "Considera estas alternativas:",
        "Content Issue": "Problema de Contenido",
        "Content Recommendations": "Recomendaciones de Contenido",
        "Content that violates community guidelines": "Contenido que viola las pautas de la comunidad",
        "Create Playlist": "Crear Lista",
        "Create your first playlist to get started": "Crea tu primera lista para empezar",
        "Delete Account": "Eliminar Cuenta",
        "Delete Conversation": "Eliminar Conversación",
        "Delete My Account": "Eliminar Mi Cuenta",
        "Deleting your account is a permanent action that cannot be undone.": "Eliminar tu cuenta es una acción permanente que no se puede deshacer.",
        "Description": "Descripción",
        "Display": "Pantalla",
        "Document": "Documento",
        "Download": "Descargar",
        "Download Account Data": "Descargar Datos de Cuenta",
        "Download Completed": "Descarga Completada",
        "Download Error": "Error de Descarga",
        "Education": "Educación",
        "Enter pod description...": "Ingresa descripción del pod...",
        "Enter pod title...": "Ingresa título del pod...",
        "Error": "Error",
        "Feature Request": "Solicitud de Función",
        "Final Confirmation": "Confirmación Final",
        "Follow Requests": "Solicitudes de Seguimiento",
        "Keyword Scoring (Debug)": "Puntuación de Palabras Clave (Depuración)",
        "Last Data Download": "Última Descarga de Datos",
        "Last Updated: March 2024": "Última Actualización: Marzo 2024",
        "Loading conversations...": "Cargando conversaciones...",
        "Mail is not configured on this device. Please contact support directly at %@": "El correo no está configurado en este dispositivo. Contacta soporte directamente en %@",
        "Member Since": "Miembro Desde",
        "Music": "Música",
        "New playlist": "Nueva lista",
        "New pod": "Nuevo pod",
        "No content to show": "No hay contenido para mostrar",
        "No conversations match your search": "No hay conversaciones que coincidan con tu búsqueda",
        "No Follow Requests": "No Hay Solicitudes de Seguimiento",
        "No playlists yet": "Aún no hay listas",
        "No pods found": "No se encontraron pods",
        "No pods in playlist": "No hay pods en la lista",
        "No reposts yet": "Aún no hay republicaciones",
        "No saved pods yet": "Aún no hay pods guardados",
        "Other": "Otro",
        "Other reasons not listed above": "Otras razones no listadas arriba",
        "Password": "Contraseña",
        "Playlists": "Listas",
        "Pod not available": "Pod no disponible",
        "Pod shared": "Pod compartido",
        "Please provide any additional details about the issue you're experiencing.": "Por favor proporciona detalles adicionales sobre el problema que estás experimentando.",
        "Processing...": "Procesando...",
        "read less": "leer menos",
        "read more": "leer más",
        "Reject": "Rechazar",
        "Remove pods from playlist": "Quitar pods de la lista",
        "Report a Problem": "Reportar un Problema",
        "Report cancelled.": "Reporte cancelado.",
        "Report Comment": "Reportar Comentario",
        "Report Pod": "Reportar Pod",
        "Report saved successfully! Since mail is not configured on this device, please contact support directly at %@": "¡Reporte guardado exitosamente! Como el correo no está configurado en este dispositivo, contacta soporte directamente en %@",
        "Report saved to drafts.": "Reporte guardado en borradores.",
        "Report sent successfully! We'll get back to you soon.": "¡Reporte enviado exitosamente! Te responderemos pronto.",
        "Report Status": "Estado del Reporte",
        "Report Submitted": "Reporte Enviado",
        "Report User": "Reportar Usuario",
        "Repost": "Republicar",
        "Repost pods you love to share with your followers": "Republica pods que te gusten para compartir con tus seguidores",
        "Reposting:": "Republicando:",
        "Reset": "Restablecer",
        "Save pods you like to find them later": "Guarda pods que te gusten para encontrarlos más tarde",
        "Saved Pods": "Pods Guardados",
        "Science": "Ciencia",
        "Selected Keywords": "Palabras Clave Seleccionadas",
        "Someone pretending to be another person": "Alguien pretendiendo ser otra persona",
        "Start a conversation with someone new": "Inicia una conversación con alguien nuevo",
        "Start conversations with friends to share pods!": "¡Inicia conversaciones con amigos para compartir pods!",
        "Submit Report": "Enviar Reporte",
        "Tags": "Etiquetas",
        "Tags (Optional)": "Etiquetas (Opcional)",
        "Test AI Categorization": "Prueba Categorización IA",
        "Test how the AI categorizes your content": "Prueba cómo la IA categoriza tu contenido",
        "This action is IRREVERSIBLE and CANNOT be undone. Your account, pods, and personal data will be permanently deleted. Are you absolutely certain you want to proceed?": "Esta acción es IRREVERSIBLE y NO SE PUEDE DESHACER. Tu cuenta, pods y datos personales serán eliminados permanentemente. ¿Estás absolutamente seguro de que quieres proceder?",
        "This action will permanently delete your account and all associated data.": "Esta acción eliminará permanentemente tu cuenta y todos los datos asociados.",
        "This user hasn't created any playlists yet": "Este usuario aún no ha creado ninguna lista",
        "This user hasn't reposted any pods yet": "Este usuario aún no ha republicado ningún pod",
        "This will prepare a copy of all your account data including profile information, pods, comments, and preferences. The download will be available shortly.": "Esto preparará una copia de todos los datos de tu cuenta incluyendo información de perfil, pods, comentarios y preferencias. La descarga estará disponible pronto.",
        "Title": "Título",
        "Try Again": "Intentar de Nuevo",
        "Try searching for a different title": "Intenta buscar un título diferente",
        "Unrepost": "Deshacer Republicación",
        "Users must not post content that is illegal, harmful, threatening, abusive, harassing, defamatory, or otherwise objectionable.": "Los usuarios no deben publicar contenido que sea ilegal, dañino, amenazante, abusivo, acosador, difamatorio u objetable de otra manera.",
        "Warning": "Advertencia",
        "We collect information you provide directly to us, including your name, email address, and profile information.": "Recopilamos información que nos proporcionas directamente, incluyendo tu nombre, dirección de correo electrónico e información de perfil.",
        "We do not sell your personal information. We may share information with service providers who assist in operating our platform.": "No vendemos tu información personal. Podemos compartir información con proveedores de servicios que ayudan a operar nuestra plataforma.",
        "We implement appropriate security measures to protect your personal information from unauthorized access.": "Implementamos medidas de seguridad apropiadas para proteger tu información personal del acceso no autorizado.",
        "We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy on this page.": "Podemos actualizar esta política de privacidad de vez en cuando. Te notificaremos de cualquier cambio publicando la nueva política en esta página.",
        "We reserve the right to terminate or suspend your account at any time for violations of these terms.": "Nos reservamos el derecho de terminar o suspender tu cuenta en cualquier momento por violaciones de estos términos.",
        "We use your information to provide, maintain, and improve our services, communicate with you, and ensure platform security.": "Usamos tu información para proporcionar, mantener y mejorar nuestros servicios, comunicarnos contigo y asegurar la seguridad de la plataforma.",
        "We're here to help you get the most out of your podcasting experience.": "Estamos aquí para ayudarte a aprovechar al máximo tu experiencia de podcasting.",
        "What do you think about this pod?": "¿Qué piensas sobre este pod?",
        "What will happen:": "Qué pasará:",
        "When people request to follow you, they'll appear here": "Cuando las personas soliciten seguirte, aparecerán aquí",
        "Yes, Delete Forever": "Sí, Eliminar para Siempre",
        "You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.": "Eres responsable de mantener la confidencialidad de la información de tu cuenta y de todas las actividades que ocurran bajo tu cuenta.",
        "You have the right to access, correct, or delete your personal information. Contact us to exercise these rights.": "Tienes derecho a acceder, corregir o eliminar tu información personal. Contáctanos para ejercer estos derechos.",
        "You must follow this user to see their content": "Debes seguir a este usuario para ver su contenido",
        "Your account data has been exported and uploaded to Firebase Storage. You can now download the JSON file using the button below, and it will be available for 30 days.": "Los datos de tu cuenta han sido exportados y subidos a Firebase Storage. Ahora puedes descargar el archivo JSON usando el botón de abajo, y estará disponible por 30 días.",
        "Your comments will remain but show as 'Anonymous User'": "Tus comentarios permanecerán pero se mostrarán como 'Usuario Anónimo'",
        "Your email will be freed for future use": "Tu correo será liberado para uso futuro",
        "Your personal information will be anonymized": "Tu información personal será anonimizada"
    }
    
    # Count translations updated
    updated_count = 0
    
    # Update all strings marked as 'needs_review' with proper Spanish translations
    for key, value in data['strings'].items():
        if key and not key.startswith('%') and not key.startswith('@'):
            if 'localizations' in value and 'es' in value['localizations']:
                if value['localizations']['es']['stringUnit']['state'] == 'needs_review':
                    if key in spanish_translations:
                        value['localizations']['es']['stringUnit']['value'] = spanish_translations[key]
                        value['localizations']['es']['stringUnit']['state'] = 'translated'
                        updated_count += 1
                        print(f"✅ Updated: {key}")
                    else:
                        print(f"⚠️  Missing translation for: {key}")
    
    # Write back to file
    with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"\n🎉 Spanish translations finalized!")
    print(f"📝 Updated {updated_count} strings from 'needs_review' to 'translated'")
    print("🔍 Check the file for any remaining strings that need manual translation")

if __name__ == "__main__":
    if not os.path.exists('Localizable.xcstrings'):
        print("❌ Localizable.xcstrings file not found in current directory")
        exit(1)
    
    finalize_spanish_translations()
