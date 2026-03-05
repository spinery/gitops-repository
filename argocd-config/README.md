# Argo CD Config

Manifiestos básicos para configurar Argo CD una vez instalado en el cluster.

## Estructura

```
argocd-config/
├── argocd-cm.yaml              # Config principal + integración Argo Rollouts
├── argocd-rbac-cm.yaml         # RBAC
├── argocd-cmd-params-cm.yaml   # Parámetros del server/repo-server
├── examples/
│   ├── project-example.yaml    # Ejemplo de AppProject
│   ├── repository-example.yaml # Ejemplo de repositorios (Git HTTPS/SSH)
│   ├── cluster-example.yaml              # Ejemplo de clusters (in-cluster y externo)
│   ├── application-manifests-example.yaml # Application: repo de manifiestos
│   └── application-helm-example.yaml      # Application: Helm chart con variables
└── README.md
```

## Archivos de configuración

| Archivo | Descripción |
|---------|-------------|
| `argocd-cm.yaml` | ConfigMap principal: timeouts, integración con **Argo Rollouts** (health + acciones Resume/Restart en la UI). |
| `argocd-rbac-cm.yaml` | ConfigMap de RBAC: políticas por defecto y opcionalmente políticas custom. |
| `argocd-cmd-params-cm.yaml` | Parámetros de los binarios (ej. `server.insecure` para desarrollo). |

## Ejemplos (examples/)

| Archivo | Descripción |
|---------|-------------|
| `examples/project-example.yaml` | **Proyecto (AppProject)**: agrupa aplicaciones y restringe `sourceRepos`, `destinations`, recursos permitidos y opcionalmente roles. |
| `examples/repository-example.yaml` | **Repositorios**: Secrets para registrar repos Git (HTTPS con usuario/contraseña, público, o SSH con clave privada). |
| `examples/cluster-example.yaml` | **Clusters**: Secrets para registrar el cluster local con nombre amigable o clusters externos (ej. otro Kind). |
| `examples/application-manifests-example.yaml` | **Application (manifiestos)**: sincroniza un directorio Git (YAML/Kustomize); ejemplo con Guestbook. |
| `examples/application-helm-example.yaml` | **Application (Helm)**: despliega un chart (Bitnami nginx) con variables en `source.helm.values` y opcionalmente `parameters`. |

## Requisitos

- Argo CD ya instalado en el cluster (por ejemplo con `./argocd-install.sh`).
- `kubectl` con contexto apuntando al cluster donde está Argo CD.

## Cómo aplicar

**Solo ConfigMaps (config base):**

```bash
kubectl apply -n argocd -f argocd-config/argocd-cm.yaml
kubectl apply -n argocd -f argocd-config/argocd-rbac-cm.yaml
kubectl apply -n argocd -f argocd-config/argocd-cmd-params-cm.yaml
```

**Incluir ejemplos (proyecto, repositorios, clusters):**

Edita antes los YAML en `examples/` (repositorios y clusters con tus URLs y credenciales). Luego:

```bash
kubectl apply -n argocd -f argocd-config/
```

O solo los ejemplos que quieras:

```bash
kubectl apply -n argocd -f argocd-config/examples/project-example.yaml
kubectl apply -n argocd -f argocd-config/examples/repository-example.yaml
kubectl apply -n argocd -f argocd-config/examples/cluster-example.yaml
kubectl apply -n argocd -f argocd-config/examples/application-manifests-example.yaml
kubectl apply -n argocd -f argocd-config/examples/application-helm-example.yaml
```

Después de cambiar `argocd-cm` o `argocd-cmd-params-cm`, suele ser necesario reiniciar el server y/o el repo-server para que carguen la nueva config:

```bash
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout restart deployment/argocd-repo-server -n argocd
```

## Argo Rollouts en la UI de Argo CD

El `argocd-cm.yaml` incluye:

- **Health check** para el CRD `Rollout` (argoproj.io): Argo CD mostrará Healthy / Progressing / Degraded / Paused según el estado del Rollout.
- **Acciones** `resume` y `restart` en la UI: al ver un recurso Rollout en una Application, podrás usar el menú de acciones para reanudar o reiniciar el rollout.

Así puedes gestionar Argo Rollouts desde la UI de Argo CD sin depender solo del plugin `kubectl argo rollouts`.
