# ERP: Odoo Community 17 contenerizado para Cloud Run
FROM odoo:17.0

USER root

# Configuración base y módulos propios (addons/ queda vacío por defecto)
COPY odoo.conf /etc/odoo/odoo.conf
COPY addons /mnt/extra-addons
COPY entrypoint-erp.sh /usr/local/bin/entrypoint-erp.sh

RUN chmod +x /usr/local/bin/entrypoint-erp.sh \
    && chown -R odoo:odoo /mnt/extra-addons /etc/odoo

USER odoo

# Cloud Run enruta al puerto 8069
EXPOSE 8069

ENTRYPOINT ["/usr/local/bin/entrypoint-erp.sh"]
CMD ["odoo"]
