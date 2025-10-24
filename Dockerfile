FROM ubuntu:24.04

# Establece el frontend de Debian en modo no interactivo para evitar preguntas durante la instalación.
ENV DEBIAN_FRONTEND=noninteractive

# 2. Instalación de dependencias: Apache, PHP y extensiones necesarias para iTop, junto con herramientas (wget, unzip, acl)
# La instalación de Apache y PHP garantiza que el usuario 'www-data' exista para los comandos de permisos (chown/setfacl).
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    apache2 \
    php8.3 \
    libapache2-mod-php8.3 \
    php8.3-mysql \
    php8.3-gd \
    php8.3-ldap \
    php8.3-cli \
    php8.3-soap \
    php8.3-xml \
    php8.3-mbstring \
    php8.3-zip \
    php8.3-curl \
    wget \
    unzip \
    acl && \
    # Limpia la caché de APT para reducir el tamaño final de la imagen.
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Establece el directorio de trabajo como la raíz de la aplicación iTop
WORKDIR /var/www/html

# 3. Descarga, Extracción y Reorganización de los archivos de iTop
# Se combinan los comandos originales del usuario para reducir capas:
# wget ... unzip ... mv ... rmdir ...
RUN wget https://sourceforge.net/projects/itop/files/latest/download -O /tmp/itop.zip && \
    unzip /tmp/itop.zip "web/*" -d . && \
    mv web/* . && \
    rmdir web && \
    rm /tmp/itop.zip

# 4. Creación de directorios y configuración de permisos (Chown y ACL)
# Se combinan los comandos originales del usuario (mkdir, chown, setfacl)
RUN mkdir env-production env-production-build env-test env-test-build && \
    # 🚨 Comando original: Asegura que el usuario 'www-data' tenga permisos de lectura/escritura/ejecución (rwX) en los directorios de datos y log, y establece estos como permisos por defecto para nuevos archivos.
    setfacl -dR -m u:"www-data":rwX data log && \
    setfacl -R -m u:"www-data":rwX data log && \
    # 🚨 Comando original: Asegura que 'www-data' tenga acceso al directorio principal.
    setfacl -m u:"www-data":rwX . && \
    # 🚨 Comando original: Establece la propiedad de los directorios de configuración y entorno para 'www-data'.
    chown -R www-data:www-data conf env-production env-production-build env-test env-test-build

# 5. Configuración del Servidor Web (Apache)
# Habilita el módulo de reescritura de URLs (mod_rewrite) y establece la configuración del sitio para iTop.
RUN a2enmod rewrite && \
    echo '<VirtualHost *:80>\n\tDocumentRoot /var/www/html\n\t<Directory /var/www/html/>\n\t\tOptions Indexes FollowSymLinks\n\t\tAllowOverride All\n\t\tRequire all granted\n\t</Directory>\n\tErrorLog ${APACHE_LOG_DIR}/error.log\n\tCustomLog ${APACHE_LOG_DIR}/access.log combined\n</VirtualHost>' > /etc/apache2/sites-available/itop.conf && \
    a2ensite itop && \
    a2dismod status
RUN rm /var/www/html/index.html

# 6. Exposición de Puerto y Comando de Ejecución
# Puerto por defecto del servidor web.
EXPOSE 80

# Comando para iniciar el servidor Apache en primer plano (necesario para Docker)
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
