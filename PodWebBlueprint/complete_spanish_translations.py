#!/usr/bin/env python3
"""
Script to complete Spanish translations for Localizable.xcstrings
This script will add Spanish translations for all strings that don't have them
"""

import json
import os

def complete_spanish_translations():
    """Complete Spanish translations for all strings"""
    
    # Read the current file
    with open('Localizable.xcstrings', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Spanish translations dictionary - comprehensive coverage
    spanish_translations = {
        # Missing translations from the file
        "%@ reposted": "%@ republicó",
        "%@'s pod": "pod de %@",
        "• Change your privacy settings": "• Cambiar tu configuración de privacidad",
        "• Delete Account: Permanently remove your account and all data": "• Eliminar Cuenta: Eliminar permanentemente tu cuenta y todos los datos",
        "• Delete specific content instead": "• Eliminar contenido específico en su lugar",
        "• Download Account Data: Get a copy of all your personal data": "• Descargar Datos de Cuenta: Obtener una copia de todos tus datos personales",
        "• Temporarily disable your account": "• Deshabilitar temporalmente tu cuenta",
        "0 likes": "0 me gusta",
        "1. Acceptance of Terms": "1. Aceptación de Términos",
        "2. How We Use Your Information": "2. Cómo Usamos Tu Información",
        "3. Information Sharing": "3. Compartir Información",
        "4. Data Security": "4. Seguridad de Datos",
        "5. Your Rights": "5. Tus Derechos",
        "6. Changes to This Policy": "6. Cambios a Esta Política",
        "About Account Actions": "Acerca de las Acciones de Cuenta",
        "Account Actions": "Acciones de Cuenta",
        "Account Deleted": "Cuenta Eliminada",
        "Account Information": "Información de Cuenta",
        "Account Settings": "Configuración de Cuenta",
        "Add a caption (optional)": "Añadir una descripción (opcional)",
        "Add a tag...": "Añadir una etiqueta...",
        "Add some pods to this playlist first": "Añade algunos pods a esta lista primero",
        "Add tags...": "Añadir etiquetas...",
        "Add to playlist": "Añadir a lista",
        "All Keywords in '%@' Category": "Todas las Palabras Clave en la Categoría '%@'",
        "All your pods will be permanently deleted": "Todos tus pods serán eliminados permanentemente",
        "Are you sure you want to delete this conversation? This action cannot be undone.": "¿Estás seguro de que quieres eliminar esta conversación? Esta acción no se puede deshacer.",
        "Are You Sure?": "¿Estás Seguro?",
        "Available": "Disponible",
        "Category": "Categoría",
        "Clear": "Limpiar",
        "Create Playlist": "Crear Lista",
        "Create your first playlist to get started": "Crea tu primera lista para empezar",
        "Delete Account": "Eliminar Cuenta",
        "Delete Conversation": "Eliminar Conversación",
        "Delete My Account": "Eliminar Mi Cuenta",
        "Delete playlist": "Eliminar lista",
        "Deleting your account is a permanent action that cannot be undone.": "Eliminar tu cuenta es una acción permanente que no se puede deshacer.",
        "Description": "Descripción",
        "Download": "Descargar",
        "Download Account Data": "Descargar Datos de Cuenta",
        "Download Completed": "Descarga Completada",
        "Download Error": "Error de Descarga",
        "Enter pod description...": "Ingresa descripción del pod...",
        "Enter pod title...": "Ingresa título del pod...",
        "Error": "Error",
        "Final Confirmation": "Confirmación Final",
        "Follow Requests": "Solicitudes de Seguimiento",
        "Keyword Scoring (Debug)": "Puntuación de Palabras Clave (Depuración)",
        "Last Data Download": "Última Descarga de Datos",
        "Loading conversations...": "Cargando conversaciones...",
        "Mail is not configured on this device. Please contact support directly at %@": "El correo no está configurado en este dispositivo. Contacta soporte directamente en %@",
        "Member Since": "Miembro Desde",
        "No content to show": "No hay contenido para mostrar",
        "No conversations match your search": "No hay conversaciones que coincidan con tu búsqueda",
        "No Follow Requests": "No Hay Solicitudes de Seguimiento",
        "No playlists yet": "Aún no hay listas",
        "No pods found": "No se encontraron pods",
        "No pods in playlist": "No hay pods en la lista",
        "No reposts yet": "Aún no hay republicaciones",
        "No saved pods yet": "Aún no hay pods guardados",
        "Other": "Otro",
        "Playlists": "Listas",
        "Pod not available": "Pod no disponible",
        "Pod shared": "Pod compartido",
        "Processing...": "Procesando...",
        "Repost": "Republicar",
        "Repost pods you love to share with your followers": "Republica pods que te gusten para compartir con tus seguidores",
        "Reposting:": "Republicando:",
        "Reset": "Restablecer",
        "Save pods you like to find them later": "Guarda pods que te gusten para encontrarlos más tarde",
        "Saved Pods": "Pods Guardados",
        "Selected Keywords": "Palabras Clave Seleccionadas",
        "Start a conversation with someone new": "Inicia una conversación con alguien nuevo",
        "Start conversations with friends to share pods!": "¡Inicia conversaciones con amigos para compartir pods!",
        "Submit Report": "Enviar Reporte",
        "Tags": "Etiquetas",
        "Tags (Optional)": "Etiquetas (Opcional)",
        "Test AI Categorization": "Probar Categorización IA",
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
        "Warning": "Advertencia",
        "What do you think about this pod?": "¿Qué piensas sobre este pod?",
        "What will happen:": "Qué pasará:",
        "When people request to follow you, they'll appear here": "Cuando las personas soliciten seguirte, aparecerán aquí",
        "You must follow this user to see their content": "Debes seguir a este usuario para ver su contenido",
        "Your account data has been exported and uploaded to Firebase Storage. You can now download the JSON file using the button below, and it will be available for 30 days.": "Los datos de tu cuenta han sido exportados y subidos a Firebase Storage. Ahora puedes descargar el archivo JSON usando el botón de abajo, y estará disponible por 30 días.",
        "Your comments will remain but show as 'Anonymous User'": "Tus comentarios permanecerán pero se mostrarán como 'Usuario Anónimo'",
        "Your email will be freed for future use": "Tu correo será liberado para uso futuro",
        "Your personal information will be anonymized": "Tu información personal será anonimizada"
    }
    
    # Count missing translations
    missing_count = 0
    added_count = 0
    
    # Add Spanish translations to all strings
    for key, value in data['strings'].items():
        if key and not key.startswith('%') and not key.startswith('@'):
            # Check if this string needs Spanish translation
            if 'localizations' not in value:
                value['localizations'] = {}
                missing_count += 1
            
            if 'es' not in value['localizations']:
                # Add Spanish translation
                if key in spanish_translations:
                    value['localizations']['es'] = {
                        'stringUnit': {
                            'state': 'translated',
                            'value': spanish_translations[key]
                        }
                    }
                    added_count += 1
                else:
                    # Use English as placeholder for missing translations
                    value['localizations']['es'] = {
                        'stringUnit': {
                            'state': 'needs_review',
                            'value': key  # Use English as placeholder
                        }
                    }
                    missing_count += 1
    
    # Write back to file
    with open('Localizable.xcstrings', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print("✅ Spanish translations completed!")
    print(f"📝 Added {added_count} proper Spanish translations")
    print(f"⚠️  {missing_count} strings still need manual Spanish translation")
    print("🔧 Check the file for strings marked as 'needs_review' and add proper Spanish translations")

if __name__ == "__main__":
    if not os.path.exists('Localizable.xcstrings'):
        print("❌ Localizable.xcstrings file not found in current directory")
        exit(1)
    
    complete_spanish_translations()
