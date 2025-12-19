# PHP Manager Ultimate

<p align="center">
  <strong>A modern, elegant PHP version manager for Windows</strong>
</p>

<p align="center">
  <a href="#english">English</a> •
  <a href="#español">Español</a>
</p>

---

<a name="english"></a>
## 🇺🇸 English

### Features

- 🎨 **Modern UI** - Glassmorphism design with dark theme
- 📥 **One-Click Downloads** - Install PHP versions directly from php.net
- ⚡ **Quick Switching** - Activate different PHP versions instantly
- 🔧 **PATH Management** - Automatic PATH configuration
- 🗑️ **Easy Uninstall** - Remove versions with one click
- 🛡️ **Wamp64 Compatible** - Resolves PATH conflicts with Wamp/Xampp
- 📊 **Debug Logging** - Configurable debug logs

### Requirements

- **OS**: Windows 10/11 (64-bit)
- **PowerShell**: Version 5.1 or higher
- **Browser**: Microsoft Edge or Google Chrome (for app mode)
- **Permissions**: Administrator recommended for PATH modifications
- **Installation Path**: Must be installed in `C:\php` (required, not configurable)

### Installation

#### Option 1: Automatic Installation
1. Download or clone this repository
2. Right-click `install.bat` → **Run as Administrator**
3. Follow the on-screen instructions

#### Option 2: Manual Installation
1. Copy all files to `C:\php\`
2. Create `C:\php\versions\` folder
3. Run: `powershell -ExecutionPolicy Bypass -File C:\php\php-manager.ps1`

### Usage

1. **Start the application**: Double-click the desktop shortcut or run `php-manager.ps1`
2. **Download PHP**: Go to "Available" tab, click "Install" on desired version
3. **Activate version**: Go to "Installed" tab, click "Activate"
4. **Verify**: Open new terminal, run `php -v`

### Configuration

Edit `C:\php\config.json` to customize:

```json
{
    "debug": {
        "launcher_debug_enabled": false,
        "server_debug_enabled": false
    },
    "server": {
        "port": 8085
    },
    "browser": {
        "use_app_mode": true
    }
}
```

---

<a name="español"></a>
## 🇪🇸 Español

### Características

- 🎨 **UI Moderna** - Diseño glassmorphism con tema oscuro
- 📥 **Descargas en Un Clic** - Instala versiones de PHP directamente de php.net
- ⚡ **Cambio Rápido** - Activa diferentes versiones de PHP al instante
- 🔧 **Gestión de PATH** - Configuración automática del PATH
- 🗑️ **Desinstalación Fácil** - Elimina versiones con un clic
- 🛡️ **Compatible con Wamp64** - Resuelve conflictos de PATH con Wamp/Xampp
- 📊 **Logs de Debug** - Logs de depuración configurables

### Requisitos

- **SO**: Windows 10/11 (64-bit)
- **PowerShell**: Version 5.1 o superior
- **Navegador**: Microsoft Edge o Google Chrome (para modo app)
- **Permisos**: Administrador recomendado para modificaciones de PATH
- **Ruta de Instalacion**: Debe instalarse en `C:\php` (obligatorio, no configurable)

### Instalación

#### Opción 1: Instalación Automática
1. Descarga o clona este repositorio
2. Clic derecho en `install.bat` → **Ejecutar como Administrador**
3. Sigue las instrucciones en pantalla

#### Opción 2: Instalación Manual
1. Copia todos los archivos a `C:\php\`
2. Crea la carpeta `C:\php\versions\`
3. Ejecuta: `powershell -ExecutionPolicy Bypass -File C:\php\php-manager.ps1`

### Uso

1. **Iniciar la aplicación**: Doble clic en el acceso directo o ejecuta `php-manager.ps1`
2. **Descargar PHP**: Ve a la pestaña "Disponibles", clic en "Instalar"
3. **Activar versión**: Ve a la pestaña "Instaladas", clic en "Activar"
4. **Verificar**: Abre una nueva terminal, ejecuta `php -v`

### Configuración

Edita `C:\php\config.json` para personalizar:

```json
{
    "debug": {
        "launcher_debug_enabled": false,
        "server_debug_enabled": false
    },
    "server": {
        "port": 8085
    },
    "browser": {
        "use_app_mode": true
    }
}
```

---

## ⚠️ Disclaimer / Aviso Legal

### English

This software retrieves PHP version information by scraping the official PHP downloads page (https://windows.php.net/download/). 

**IMPORTANT NOTICE:**
- This tool is provided "AS IS" without warranty of any kind
- Web scraping may violate the terms of service of php.net
- The developers are NOT responsible for:
  - Any misuse of this software
  - Changes to php.net that may break functionality
  - Any legal issues arising from the use of web scraping
  - Data accuracy or availability
- Use this software at your own risk
- This is an unofficial tool and is not affiliated with The PHP Group

**Recommendation**: For production environments, download PHP manually from the official source.

**Repository Removal**: This repository will be removed immediately if requested by The PHP Group or php.net administrators.

### Español

Este software obtiene información de versiones de PHP mediante scraping de la página oficial de descargas de PHP (https://windows.php.net/download/).

**AVISO IMPORTANTE:**
- Esta herramienta se proporciona "TAL CUAL" sin garantía de ningún tipo
- El web scraping puede violar los términos de servicio de php.net
- Los desarrolladores NO son responsables de:
  - Cualquier mal uso de este software
  - Cambios en php.net que puedan afectar la funcionalidad
  - Cualquier problema legal derivado del uso de web scraping
  - Precisión o disponibilidad de los datos
- Use este software bajo su propio riesgo
- Esta es una herramienta no oficial y no está afiliada con The PHP Group

**Recomendación**: Para entornos de producción, descargue PHP manualmente de la fuente oficial.

**Eliminación del Repositorio**: Este repositorio será eliminado inmediatamente si lo solicita The PHP Group o los administradores de php.net.

---

## 📄 License / Licencia

MIT License - See [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

<p align="center">
  Made with ❤️ for the PHP community
</p>
