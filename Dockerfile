# Utiliser l'image d'Ubuntu comme base
FROM ubuntu:20.04
# Récupérer les variables d'environnement
ARG LDAP_ADMIN_PASSWORD
ARG NOM_DE_DOMAINE
ARG DC
ARG DC2
ARG FREERADIUS_SECRETE
# Définir les variables d'environnement précedente dans l'image
ENV LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD} \
    NOM_DE_DOMAINE=${NOM_DE_DOMAINE} \
    DC=${DC} \
    FREERADIUS_SECRETE=${FREERADIUS_SECRETE} \
    DC2=${DC2} 
# Exposer les ports appropriés
EXPOSE 80/tcp
EXPOSE 389/tcp
EXPOSE 1812/udp
EXPOSE 1813/udp
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
#ldap.conf
RUN sed -i "s|TLS_CACERT|#TLS_CACERT|g"  /etc/ldap/ldap.conf
#copy de la configue phpldapadmin connection web
COPY config.php /etc/phpldapadmin/config.php
#modif de la config phpldapadmin d'apré notre dn et notre mdp depuis nos var
RUN sed -i "s|dc=exemple|dc=${DC}|g" /etc/phpldapadmin/config.php
RUN sed -i "s|dc=local|dc=${DC2}|g" /etc/phpldapadmin/config.php
RUN sed -i "s|('login','bind_pass','defaultpw')|('login','bind_pass','${LDAP_ADMIN_PASSWORD}')|g" /etc/phpldapadmin/config.php
RUN sed -i "s|('server','name','ldap.exemple.local')|('server','name','ldap.${NOM_DE_DOMAINE}')|g" /etc/phpldapadmin/config.php
#copy des user preconf
COPY grpusr.ldif /usr/local/bin/grpusr.ldif
RUN sed -i "s|exemple|${DC}|g" /usr/local/bin/grpusr.ldif
RUN sed -i "s|local|${DC2}|g" /usr/local/bin/grpusr.ldif
COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh
RUN sed -i "s|dc=exemple|dc=${DC}|g" /usr/local/bin/script.sh
RUN sed -i "s|dc=local|dc=${DC2}|g" /usr/local/bin/script.sh
RUN sed -i "s|defaultpw|${LDAP_ADMIN_PASSWORD}|g" /usr/local/bin/script.sh
#remove default conf
RUN rm /etc/freeradius/3.0/sites-enabled/default
RUN rm /etc/freeradius/3.0/mods-enabled/eap
COPY eap /etc/freeradius/3.0/mods-enabled/eap
#RUN cp /etc/freeradius/3.0/sites-available/inner-tunnel /etc/freeradius/3.0/sites-enabled/
#copy des config et modif celon les var
COPY ldap /etc/freeradius/3.0/mods-enabled/
RUN sed -i "s|dc=exemple,dc=locala|dc=${DC},dc=${DC2}|g" /etc/freeradius/3.0/mods-enabled/ldap
RUN sed -i "s|defaultpw|${LDAP_ADMIN_PASSWORD}|g" /etc/freeradius/3.0/mods-enabled/ldap
COPY clients.conf /etc/freeradius/3.0/
RUN sed -i "s|testing123|${FREERADIUS_SECRETE}|g" /etc/freeradius/3.0/clients.conf
#RUN sed -i "s|defaultpw|${FREERADIUS_SECRETE}|g" /etc/freeradius/3.0/mods-enabled/ldap
COPY my_server /etc/freeradius/3.0/sites-enabled/
# atribution du nom du server
RUN echo "ServerName ldap.${NOM_DE_DOMAINE}" >> /etc/apache2/apache2.conf
# Définir le point d'entrée pour le conteneur
CMD service slapd start && \
    service freeradius start && \
    apache2ctl -DFOREGROUND && \
    ./usr/local/bin/script.sh
#RUN ldapadd -x -D "cn=admin,dc=${DN},dc=${DC2}" -w ${LDAP_ADMIN_PASSWORD} -f /usr/local/bin/grpusr.ldif