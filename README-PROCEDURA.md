# 🔌 Installazione Plugin NetBox Topology Views su RKE2/Kubernetes

## Panoramica

Questa procedura installa il plugin **netbox-topology-views v4.5.0** nel tuo NetBox v4.5.1
deployato via Helm su cluster RKE2, **senza usare Docker locale e senza modificare i pod in runtime**.

### Flusso operativo
```
[1. Push su GitHub] → [2. GitHub Actions builda immagine] → [3. Push su ghcr.io]
→ [4. helm upgrade con nuova immagine] → [5. migrate] → [6. Plugin attivo! ✅]
```

### File di questo progetto
| File | Scopo |
|---|---|
| `Dockerfile` | Estende l'immagine NetBox ufficiale con il plugin |
| `plugin_requirements.txt` | Lista dei plugin Python da installare |
| `.github/workflows/build-netbox.yml` | CI/CD: build automatica e push su ghcr.io |
| `values-topology.yaml` | Helm values completi (tuoi originali + plugin) |

---

## 📋 PREREQUISITI

- [x] Account GitHub: `brennomessana`
- [ ] Git installato sul PC (già disponibile)
- [ ] Accesso kubectl al cluster RKE2 (già configurato)
- [ ] Helm installato (già disponibile)

---

## FASE 1: Creare il Repository GitHub

### 1.1 Crea il repo su GitHub

Vai su https://github.com/new e crea un nuovo repository:
- **Nome**: `netbox-custom`
- **Visibilità**: **Public** (così ghcr.io è accessibile senza pull secret)
  - ⚠️ Se scegli Private, dovrai creare un imagePullSecret (vedi sezione Troubleshooting)
- **NON** inizializzare con README (lo faremo noi)

### 1.2 Inizializza e pusha il repository locale

Apri un terminale nella cartella `netbox-custom` sul tuo Desktop:

```bash
cd C:\Users\brenn\Desktop\netbox-custom

# Inizializza git
git init
git branch -M main

# Aggiungi tutti i file
git add .

# Primo commit
git commit -m "feat: NetBox custom image con plugin netbox-topology-views"

# Collega al repo remoto
git remote add origin https://github.com/brennomessana/netbox-custom.git

# Push
git push -u origin main
```

> **NOTA**: Al push ti verrà chiesto di autenticarti.
> Usa un **Personal Access Token (PAT)** come password.
> Crealo da: https://github.com/settings/tokens → "Generate new token (classic)"
> Seleziona i permessi: `repo`, `write:packages`, `read:packages`

---

## FASE 2: Attendere la Build Automatica

### 2.1 Verifica che GitHub Actions parta

1. Vai su: https://github.com/brennomessana/netbox-custom/actions
2. Dovresti vedere il workflow "Build NetBox Custom Image" in esecuzione
3. Attendi che diventi verde ✅ (circa 3-5 minuti)

### 2.2 Verifica l'immagine su GHCR

1. Vai su: https://github.com/brennomessana/netbox-custom/pkgs/container/netbox-custom
2. Dovresti vedere i tag: `v4.5.1-topology` e `latest`

### 2.3 Rendi il package pubblico (IMPORTANTE se il repo è pubblico)

1. Vai su: https://github.com/users/brennomessana/packages/container/netbox-custom/settings
2. Nella sezione "Danger Zone", clicca **"Change visibility"**
3. Seleziona **"Public"**
4. Conferma

> Questo è necessario perché per default i packages GHCR sono privati,
> anche se il repo sorgente è pubblico.

---

## FASE 3: Deploy su Kubernetes

### 3.1 Copia il values file sul nodo (o usa kubectl dalla tua macchina)

Se usi kubectl dal tuo PC Windows:
```bash
# Il file values-topology.yaml è già sul tuo Desktop
```

Se devi copiarlo sul nodo SUSE:
```bash
scp C:\Users\brenn\Desktop\netbox-custom\values-topology.yaml brenno@192.168.1.38:~/
```

### 3.2 Esegui Helm Upgrade

```bash
helm upgrade netbox netbox-community/netbox \
  --namespace netbox452 \
  -f values-topology.yaml \
  --wait \
  --timeout 10m
```

> **Cosa succede**: Helm rileverà che l'immagine è cambiata e ricreerà i pod.
> I pod netbox e netbox-worker verranno ricreati con la nuova immagine che
> include il plugin. PostgreSQL e Valkey NON verranno toccati.

### 3.3 Monitora il rollout

```bash
# Guarda lo stato dei pod in tempo reale
kubectl get pods -n netbox452 -w

# Aspetta che il deployment sia pronto
kubectl rollout status deployment/netbox -n netbox452 --timeout=300s
kubectl rollout status deployment/netbox-worker -n netbox452 --timeout=300s
```

---

## FASE 4: Migrazioni del Plugin

Il plugin netbox-topology-views ha modelli database propri. Devi eseguire le migrazioni:

```bash
# Esegui le migrazioni del plugin
kubectl exec -n netbox452 deploy/netbox -- \
  /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py migrate netbox_topology_views

# Verifica che le migrazioni siano state applicate
kubectl exec -n netbox452 deploy/netbox -- \
  /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py showmigrations netbox_topology_views
```

Output atteso per `showmigrations`:
```
netbox_topology_views
 [X] 0001_initial
 [X] 0002_...
 ...
```

---

## FASE 5: Verifica dell'Installazione

### 5.1 Controlla che i pod siano Running

```bash
kubectl get pods -n netbox452
```

Output atteso:
```
NAME                             READY   STATUS    RESTARTS   AGE
netbox-xxxxx-yyyyy               1/1     Running   0          2m
netbox-worker-xxxxx-yyyyy        1/1     Running   0          2m
netbox-postgresql-0              1/1     Running   0          ...
netbox-valkey-primary-0          1/1     Running   0          ...
```

### 5.2 Controlla i log per errori

```bash
# Log del pod NetBox principale
kubectl logs -n netbox452 deploy/netbox --tail=100

# Cerca specificamente errori relativi al plugin
kubectl logs -n netbox452 deploy/netbox --tail=100 | grep -i "plugin\|topology\|error\|exception"
```

### 5.3 Verifica il plugin via Django shell

```bash
kubectl exec -n netbox452 deploy/netbox -- \
  /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py shell -c \
  "from django.conf import settings; print('PLUGINS:', settings.PLUGINS); print('CONFIG:', settings.PLUGINS_CONFIG)"
```

Output atteso:
```
PLUGINS: ['netbox_topology_views']
CONFIG: {'netbox_topology_views': {'preselected_device_roles': ['Router', 'Firewall', 'Switch'], ...}}
```

### 5.4 Verifica via API di stato

```bash
kubectl exec -n netbox452 deploy/netbox -- \
  curl -s http://localhost:8080/api/status/ 2>/dev/null | python3 -m json.tool | grep -A5 plugins
```

### 5.5 Verifica dalla UI Web

1. Apri il browser: `http://192.168.1.38:32571`
2. Effettua il login
3. Nel menu laterale dovresti vedere una nuova voce **"Topology Views"** o **"Plugins → Topology Views"**
4. Cliccaci per vedere la mappa topologica dei tuoi device

---

## 🔧 TROUBLESHOOTING

### Problema: ImagePullBackOff

Se i pod mostrano `ImagePullBackOff`:

```bash
kubectl describe pod -n netbox452 -l app.kubernetes.io/name=netbox | grep -A5 "Events"
```

**Causa probabile**: L'immagine su ghcr.io è privata.

**Soluzione A** - Rendi pubblica l'immagine (raccomandato):
- Vai su https://github.com/users/brennomessana/packages/container/netbox-custom/settings
- Cambia visibilità in Public

**Soluzione B** - Crea un pull secret:
```bash
# Crea un PAT su GitHub con permesso read:packages
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace netbox452 \
  --docker-server=ghcr.io \
  --docker-username=brennomessana \
  --docker-password=<IL_TUO_GITHUB_PAT>
```

Poi aggiungi nel `values-topology.yaml`:
```yaml
image:
  pullSecrets:
    - name: ghcr-pull-secret
```

E rifai `helm upgrade`.

### Problema: CrashLoopBackOff dopo upgrade

```bash
# Controlla i log per capire l'errore
kubectl logs -n netbox452 deploy/netbox --previous

# Se necessario, rollback alla versione precedente
helm rollback netbox -n netbox452
```

### Problema: Plugin non appare nel menu

1. Verifica che `plugins` sia configurato correttamente:
```bash
kubectl exec -n netbox452 deploy/netbox -- \
  /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py shell -c \
  "from django.conf import settings; print(settings.PLUGINS)"
```

2. Verifica che il pacchetto Python sia installato:
```bash
kubectl exec -n netbox452 deploy/netbox -- \
  /opt/netbox/venv/bin/pip list | grep topology
```

Output atteso:
```
netbox-topology-views    4.5.0
```

### Problema: Errore "No module named 'netbox_topology_views'"

L'immagine non contiene il plugin. Verifica che la build GitHub Actions sia andata a buon fine
e che stai usando l'immagine corretta:

```bash
kubectl get deploy netbox -n netbox452 -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Deve mostrare: `ghcr.io/brennomessana/netbox-custom:v4.5.1-topology`

---

## 🔄 AGGIORNAMENTI FUTURI

### Aggiornare il plugin

1. Modifica `plugin_requirements.txt` con la nuova versione
2. Se necessario, aggiorna il tag nel `Dockerfile` (es. nuova versione NetBox)
3. Commit e push:
```bash
git add .
git commit -m "chore: aggiorna netbox-topology-views a vX.Y.Z"
git push
```
4. Attendi la build su GitHub Actions
5. Esegui helm upgrade:
```bash
helm upgrade netbox netbox-community/netbox -n netbox452 -f values-topology.yaml
```
6. Esegui le migrazioni se necessario:
```bash
kubectl exec -n netbox452 deploy/netbox -- \
  /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py migrate netbox_topology_views
```

### Aggiungere altri plugin

1. Aggiungi il pacchetto a `plugin_requirements.txt`:
```
netbox-topology-views==4.5.0
altro-plugin==X.Y.Z
```

2. Aggiungi al `values-topology.yaml`:
```yaml
plugins:
  - netbox_topology_views
  - altro_plugin

pluginsConfig:
  netbox_topology_views:
    ...
  altro_plugin:
    ...
```

3. Commit, push, attendi build, helm upgrade, migrate.

---

## 📊 Riepilogo Architettura

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Repository                     │
│              brennomessana/netbox-custom                 │
│  ┌─────────────┐  ┌────────────────────────────────┐   │
│  │ Dockerfile   │  │ .github/workflows/             │   │
│  │ plugin_req.. │  │   build-netbox.yml             │   │
│  └─────────────┘  └──────────┬─────────────────────┘   │
│                               │ (push su main)          │
└───────────────────────────────┼─────────────────────────┘
                                │
                    ┌───────────▼──────────┐
                    │   GitHub Actions     │
                    │   Build Docker Image │
                    └───────────┬──────────┘
                                │
                    ┌───────────▼──────────┐
                    │      ghcr.io         │
                    │ brennomessana/       │
                    │ netbox-custom:       │
                    │ v4.5.1-topology      │
                    └───────────┬──────────┘
                                │
                    ┌───────────▼──────────┐
                    │  Cluster RKE2        │
                    │  helm upgrade        │
                    │  -f values-topology  │
                    │                      │
                    │  ┌────────────────┐  │
                    │  │ Pod: netbox    │  │
                    │  │ (custom image) │  │
                    │  │ + topology     │  │
                    │  │   views plugin │  │
                    │  └────────────────┘  │
                    └──────────────────────┘
```
