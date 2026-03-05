###############################################################################
# Dockerfile: NetBox Custom con Plugin netbox-topology-views
# Base: ghcr.io/netbox-community/netbox:v4.5.1 (immagine ufficiale community)
#
# Questo Dockerfile:
# 1. Parte dall'immagine ufficiale NetBox v4.5.1
# 2. Installa il plugin netbox-topology-views tramite uv pip
# 3. Configura temporaneamente il plugin per collectstatic
# 4. Esegue collectstatic per raccogliere i file statici (JS, CSS) del plugin
# 5. Patcha vis-network per linee rette nella topologia
###############################################################################
FROM ghcr.io/netbox-community/netbox:v4.5.1

# Copia la lista dei plugin da installare
COPY ./plugin_requirements.txt /opt/netbox/

# Installa i plugin usando uv (il package manager usato dall'immagine ufficiale)
RUN /usr/local/bin/uv pip install --no-cache -r /opt/netbox/plugin_requirements.txt

# Configura temporaneamente il plugin per collectstatic
# Questo file viene rimosso alla fine — al runtime lo monta Helm dal ConfigMap
RUN printf 'PLUGINS = ["netbox_topology_views"]\nPLUGINS_CONFIG = {}\n' > /etc/netbox/config/plugins.py

# Icone custom netbox-topology-views
COPY ./icons/ /opt/netbox/netbox/static/netbox_topology_views/img/

# Raccoglie i file statici del plugin (CSS, JS necessari per disegnare la topologia)
RUN SECRET_KEY="build-only-dummy-key-not-used-in-production-1234567890" \
    /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py collectstatic --no-input

# Rimuovi plugins.py temporaneo — verrà montato da Helm al runtime
RUN rm /etc/netbox/config/plugins.py

# Patch vis-network: linee rette invece di curve (tutte le occorrenze)
RUN sed -i 's/smooth:{enabled:!0/smooth:{enabled:!1/g' /opt/netbox/netbox/static/netbox_topology_views/js/app.js
