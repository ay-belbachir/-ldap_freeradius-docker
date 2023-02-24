# Utiliser l'image d'Ubuntu comme base
FROM ubuntu:20.04
# Récupérer les variables d'environnement
ARG LDAP_ADMIN_PASSWORD
ARG NOM_DE_DOMAINE
# Définir les variables d'environnement précedente dans l'image
ENV LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD} \
    NOM_DE_DOMAINE=${NOM_DE_DOMAINE}
#variable pour apache
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# Mettre à jour les paquets et installer les dépendances nécessaires
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y freeradius freeradius-ldap phpldapadmin nano 
#ldap conf
RUN echo "slapd slapd/internal/generated_adminpw password ${LDAP_ADMIN_PASSWORD}" | debconf-set-selections
RUN echo "slapd slapd/internal/adminpw password ${LDAP_ADMIN_PASSWORD}" | debconf-set-selections
RUN echo "slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}" | debconf-set-selections
RUN echo "slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD}" | debconf-set-selections
RUN echo "slapd slapd/domain string ${NOM_DE_DOMAINE}" | debconf-set-selections
RUN echo "slapd shared/organization string ${NOM_DE_DOMAINE}" | debconf-set-selections
RUN echo "slapd slapd/backend string HDB" | debconf-set-selections
RUN echo "slapd slapd/purge_database boolean true" | debconf-set-selections
RUN echo "slapd slapd/move_old_database boolean true" | debconf-set-selections
RUN echo "slapd slapd/allow_ldap_v2 boolean false" | debconf-set-selections
RUN echo "slapd slapd/no_configuration boolean false" | debconf-set-selections
#instalaion sldap
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y slapd ldap-utils 
# atribution du nom du server
RUN echo "ServerName itic.rockstar.com" >> /etc/apache2/apache2.conf
#copy de la configue version web
COPY config.php /etc/phpldapadmin/config.php
#remove default conf
RUN rm /etc/freeradius/3.0/sites-enabled/default
RUN rm /etc/freeradius/3.0/sites-enabled/inner-tunnel
RUN rm /etc/freeradius/3.0/mods-enabled/eap
#copy des config
COPY ldap /etc/freeradius/3.0/mods-enabled/
COPY clients.conf /etc/freeradius/3.0/
COPY my_server /etc/freeradius/3.0/sites-enabled/
# Exposer les ports appropriés
EXPOSE 80/tcp
EXPOSE 389/tcp
EXPOSE 1812/udp
EXPOSE 1813/udp

# Définir le point d'entrée pour le conteneur
CMD service slapd start && \
    service freeradius start && \
    apache2ctl -DFOREGROUND
