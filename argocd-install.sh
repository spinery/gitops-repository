#!/usr/bin/env bash
set -euo pipefail

# Script para instalar o desinstalar Argo CD en el cluster de Kubernetes actual.
# Requisitos: kubectl configurado y apuntando al cluster deseado.
# Documentación: https://argo-cd.readthedocs.io/

ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_INSTALL_URL="${ARGOCD_INSTALL_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"

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

# --- Instalar Argo CD ---
install_argocd() {
  echo "=== Instalando Argo CD ==="
  echo "Manifiesto: $ARGOCD_INSTALL_URL"
  echo "Namespace: $ARGOCD_NAMESPACE"
  echo ""

  if kubectl get namespace "$ARGOCD_NAMESPACE" &>/dev/null; then
    echo "El namespace '$ARGOCD_NAMESPACE' ya existe."
  else
    echo "Creando namespace '$ARGOCD_NAMESPACE'..."
    kubectl create namespace "$ARGOCD_NAMESPACE"
  fi

  echo "Aplicando manifiestos (server-side apply por límite de tamaño de CRDs)..."
  kubectl apply -n "$ARGOCD_NAMESPACE" --server-side --force-conflicts -f "$ARGOCD_INSTALL_URL"

  echo ""
  echo "Esperando a que los pods estén listos..."
  sleep 5
  kubectl wait --for=condition=Available deployment/argocd-server -n "$ARGOCD_NAMESPACE" --timeout=300s 2>/dev/null || true
  kubectl wait --for=condition=Available deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE" --timeout=300s 2>/dev/null || true
  kubectl wait --for=condition=Available deployment/argocd-applicationset-controller -n "$ARGOCD_NAMESPACE" --timeout=120s 2>/dev/null || true

  echo ""
  echo "=== Argo CD instalado ==="
  kubectl get pods -n "$ARGOCD_NAMESPACE"
  echo ""
  echo "--- Acceso a la UI ---"
  echo "1. Port-forward (en otra terminal):"
  echo "   kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
  echo ""
  echo "2. Abre https://localhost:8080 (acepta el certificado autofirmado si el navegador lo pide)."
  echo ""
  echo "3. Usuario: admin"
  echo "   Contraseña inicial (obtener con):"
  echo "   kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
  echo ""
}

# --- Desinstalar Argo CD ---
uninstall_argocd() {
  echo "=== Desinstalando Argo CD ==="
  echo "Namespace: $ARGOCD_NAMESPACE"
  echo ""

  if ! kubectl get namespace "$ARGOCD_NAMESPACE" &>/dev/null; then
    echo "El namespace '$ARGOCD_NAMESPACE' no existe. Nada que desinstalar." >&2
    exit 0
  fi

  echo "Eliminando recursos del manifiesto..."
  kubectl delete -n "$ARGOCD_NAMESPACE" -f "$ARGOCD_INSTALL_URL" --ignore-not-found --timeout=120s 2>/dev/null || true

  echo "Eliminando CRDs de Argo CD..."
  for crd in applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io; do
    kubectl delete crd "$crd" --ignore-not-found --timeout=60s 2>/dev/null || true
  done

  echo "Eliminando namespace '$ARGOCD_NAMESPACE'..."
  kubectl delete namespace "$ARGOCD_NAMESPACE" --timeout=180s --ignore-not-found 2>/dev/null || true

  echo ""
  echo "=== Argo CD desinstalado ==="
}

# --- Menú principal ---
main() {
  check_kubectl

  echo "=== Argo CD - Instalar / Desinstalar ==="
  echo "Cluster/contexto actual: $(kubectl config current-context)"
  echo ""
  echo "¿Qué deseas hacer?"
  echo "  1) Instalar Argo CD"
  echo "  2) Desinstalar Argo CD"
  echo "  3) Salir"
  echo ""

  read -rp "Opción (1-3): " option
  option="$(echo "$option" | xargs)"

  case "$option" in
    1)
      install_argocd
      ;;
    2)
      uninstall_argocd
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
