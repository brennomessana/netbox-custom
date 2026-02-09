###############################################################################
# Dockerfile: NetBox Custom con Plugin netbox-topology-views
# Base: ghcr.io/netbox-community/netbox:v4.5.1 (immagine ufficiale community)
#
# Questo Dockerfile:
# 1. Parte dall'immagine ufficiale NetBox v4.5.1
# 2. Installa il plugin netbox-topology-views tramite uv pip
#
# NOTA: collectstatic NON serve qui perché l'entrypoint dell'immagine
#       ufficiale lo esegue automaticamente all'avvio del container.
#
# La build avviene automaticamente via GitHub Actions (vedi .github/workflows/)
###############################################################################

FROM ghcr.io/netbox-community/netbox:v4.5.1

# Copia la lista dei plugin da installare
COPY ./plugin_requirements.txt /opt/netbox/

# Installa i plugin usando uv (il package manager usato dall'immagine ufficiale)
RUN /usr/local/bin/uv pip install --no-cache -r /opt/netbox/plugin_requirements.txt
