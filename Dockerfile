###############################################################################
# Dockerfile: NetBox Custom con Plugin netbox-topology-views
# Base: ghcr.io/netbox-community/netbox:v4.5.1 (immagine ufficiale community)
#
# Questo Dockerfile:
# 1. Parte dall'immagine ufficiale NetBox v4.5.1
# 2. Installa il plugin netbox-topology-views tramite uv pip
# 3. Esegue collectstatic per includere i file statici del plugin
#
# Build locale (opzionale):
#   docker build -t ghcr.io/brennomessana/netbox-custom:v4.5.1-topology .
#
# La build avviene automaticamente via GitHub Actions (vedi .github/workflows/)
###############################################################################

FROM ghcr.io/netbox-community/netbox:v4.5.1

# Copia la lista dei plugin da installare
COPY ./plugin_requirements.txt /opt/netbox/

# Installa i plugin usando uv (il package manager usato dall'immagine ufficiale)
RUN /usr/local/bin/uv pip install --no-cache -r /opt/netbox/plugin_requirements.txt

# Collectstatic: necessario per i file statici del plugin (CSS, JS, icone)
# SECRET_KEY dummy usata solo durante la build, non in produzione
RUN SECRET_KEY="dummy-key-only-for-collectstatic-build-step" \
    /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py collectstatic --no-input
