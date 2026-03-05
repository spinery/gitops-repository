#!/usr/bin/env bash
set -euo pipefail

# Script para instalar o desinstalar Argo Rollouts en el cluster de Kubernetes actual.
# Requisitos: kubectl configurado y apuntando al cluster deseado.
# Documentación: https://argoproj.github.io/argo-rollouts/

ARGOROLLOUTS_INSTALL_URL="${ARGOROLLOUTS_INSTALL_URL:-https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml}"
ARGOROLLOUTS_NAMESPACE="${ARGOROLLOUTS_NAMESPACE:-argo-rollouts}"

# --- Comprobar que kubectl está disponible y hay cluster ---
check_kubectl() {
  if ! command -v kubectl &>/dev/null; then
    echo "Error: kubectl no está instalado o no está en el PATH." >&2
    exit 1
  fi
  if ! kubectl cluster-info &>/dev/null; then
    echo "Error: No hay un cluster accesible. Comprueba el contexto: kubectl config current-context" >&2
    exit 1
  fi
}

# --- Instalar Argo Rollouts ---
install_rollouts() {
  echo "=== Instalando Argo Rollouts ==="
  echo "Manifiesto: $ARGOROLLOUTS_INSTALL_URL"
  echo "Namespace: $ARGOROLLOUTS_NAMESPACE"
  echo ""

  if kubectl get namespace "$ARGOROLLOUTS_NAMESPACE" &>/dev/null; then
    echo "El namespace '$ARGOROLLOUTS_NAMESPACE' ya existe."
  else
    echo "Creando namespace '$ARGOROLLOUTS_NAMESPACE'..."
    kubectl create namespace "$ARGOROLLOUTS_NAMESPACE"
  fi

  echo "Aplicando manifiestos..."
  kubectl apply -n "$ARGOROLLOUTS_NAMESPACE" -f "$ARGOROLLOUTS_INSTALL_URL"

  echo ""
  echo "Esperando a que los pods estén listos..."
  kubectl rollout status deployment/argo-rollouts -n "$ARGOROLLOUTS_NAMESPACE" --timeout=120s 2>/dev/null || true

  echo ""
  echo "=== Argo Rollouts instalado ==="
  kubectl get pods -n "$ARGOROLLOUTS_NAMESPACE"
  echo ""
  echo "Opcional: instala el plugin de kubectl para gestionar rollouts desde la CLI:"
  echo "  brew install argoproj/tap/kubectl-argo-rollouts"
}

# --- Desinstalar Argo Rollouts ---
uninstall_rollouts() {
  echo "=== Desinstalando Argo Rollouts ==="
  echo "Namespace: $ARGOROLLOUTS_NAMESPACE"
  echo ""

  if ! kubectl get namespace "$ARGOROLLOUTS_NAMESPACE" &>/dev/null; then
    echo "El namespace '$ARGOROLLOUTS_NAMESPACE' no existe. Nada que desinstalar." >&2
    exit 0
  fi

  echo "Eliminando recursos del manifiesto..."
  kubectl delete -n "$ARGOROLLOUTS_NAMESPACE" -f "$ARGOROLLOUTS_INSTALL_URL" --ignore-not-found --timeout=60s 2>/dev/null || true

  echo "Eliminando CRDs de Argo Rollouts..."
  kubectl get crd -o name 2>/dev/null | grep -E 'rollouts\.argoproj\.io' | while read -r crd; do
    kubectl delete "$crd" --timeout=60s 2>/dev/null || true
  done

  echo "Eliminando namespace '$ARGOROLLOUTS_NAMESPACE'..."
  kubectl delete namespace "$ARGOROLLOUTS_NAMESPACE" --timeout=120s --ignore-not-found 2>/dev/null || true

  echo ""
  echo "=== Argo Rollouts desinstalado ==="
}

# --- Menú principal ---
main() {
  check_kubectl

  echo "=== Argo Rollouts - Instalar / Desinstalar ==="
  echo "Cluster/contexto actual: $(kubectl config current-context)"
  echo ""
  echo "¿Qué deseas hacer?"
  echo "  1) Instalar Argo Rollouts"
  echo "  2) Desinstalar Argo Rollouts"
  echo "  3) Salir"
  echo ""

  read -rp "Opción (1-3): " option
  option="$(echo "$option" | xargs)"

  case "$option" in
    1)
      install_rollouts
      ;;
    2)
      uninstall_rollouts
      ;;
    3)
      echo "Salir."
      exit 0
      ;;
    *)
      echo "Opción no válida." >&2
      exit 1
      ;;
  esac
}

main "$@"
