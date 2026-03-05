#!/usr/bin/env bash
set -euo pipefail

# Script para crear o eliminar clusters de Kubernetes con Kind usando configs desde la carpeta clusters/
# Requisitos: Docker en ejecución, Kind instalado
# Documentación: https://kind.sigs.k8s.io/docs/user/configuration/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTERS_DIR="${SCRIPT_DIR}/clusters"

# --- Verificaciones iniciales ---
check_prerequisites() {
  if ! docker info &>/dev/null; then
    echo "Error: Docker no está en ejecución. Inicia Docker y vuelve a intentar."
    exit 1
  fi
  if ! command -v kind &>/dev/null; then
    echo "Error: Kind no está instalado."
    echo "Instálalo con: brew install kind"
    echo "O: curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-$(uname)-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind"
    exit 1
  fi
}

# --- Listar archivos de config en clusters/ (un path por línea) ---
list_config_files() {
  if [[ -d "$CLUSTERS_DIR" ]]; then
    find "$CLUSTERS_DIR" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | sort
  fi
}

# --- Obtener nombre del cluster desde un archivo YAML ---
get_cluster_name_from_config() {
  local config_file="$1"
  local name
  name="$(grep -E '^\s*name:\s*' "$config_file" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*name:[[:space:]]*//' | sed 's/^["'\'']//;s/["'\'']$//' | tr -d '\r' | xargs)" || true
  echo "${name:-kind}"
}

# --- Menú: seleccionar archivo de config ---
select_config_file() {
  local configs=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && configs+=("$line")
  done < <(list_config_files)
  if [[ ${#configs[@]} -eq 0 ]]; then
    echo "No hay archivos de configuración (.yaml o .yml) en: $CLUSTERS_DIR" >&2
    echo "Crea al menos un archivo según https://kind.sigs.k8s.io/docs/user/configuration/" >&2
    exit 1
  fi

  echo "Archivos de configuración en clusters/:" >&2
  echo "" >&2
  local i=1
  for f in "${configs[@]}"; do
    echo "  $i) $(basename "$f")" >&2
    ((i++)) || true
  done
  echo "  $i) Cancelar" >&2
  echo "" >&2

  local choice
  read -rp "Selecciona un archivo (ingresa el número 1-$i): " choice
  choice="$(echo "$choice" | xargs)"

  # Cancelar
  if [[ "$choice" == "Cancelar" || "$choice" == "$i" ]]; then
    echo "Cancelado." >&2
    exit 0
  fi

  # Por número
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice < i )); then
    echo "${configs[$((choice - 1))]}"
    return
  fi

  # Por nombre de archivo (ej: kind.yaml)
  local f
  for f in "${configs[@]}"; do
    if [[ "$(basename "$f")" == "$choice" ]]; then
      echo "$f"
      return
    fi
  done

  echo "Selección no válida (usa el número o el nombre del archivo)." >&2
  exit 1
}

# --- Crear cluster con el config seleccionado ---
create_cluster() {
  local CONFIG_FILE="$1"
  local CLUSTER_NAME
  CLUSTER_NAME="$(get_cluster_name_from_config "$CONFIG_FILE")"

  echo ""
  echo "=== Creando cluster con: $(basename "$CONFIG_FILE") (nombre: $CLUSTER_NAME) ==="
  echo ""

  if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "Ya existe un cluster '$CLUSTER_NAME'. Eliminándolo primero..."
    kind delete cluster --name "$CLUSTER_NAME"
  fi

  echo "Creando cluster '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_FILE"

  echo ""
  echo "Configurando contexto de kubectl..."
  kubectl config use-context "kind-${CLUSTER_NAME}"

  echo ""
  echo "=== Validando con 'kubectl get nodes' ==="
  kubectl get nodes

  echo ""
  echo "=== Listo ==="
  echo "Cluster '$CLUSTER_NAME' creado. Contexto: $(kubectl config current-context)"
}

# --- Menú: seleccionar cluster a eliminar ---
select_cluster_to_delete() {
  local clusters=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && clusters+=("$line")
  done < <(kind get clusters 2>/dev/null) || true
  if [[ ${#clusters[@]} -eq 0 ]]; then
    echo "No hay clusters Kind en ejecución." >&2
    return 1
  fi

  echo "Clusters Kind existentes:" >&2
  echo "" >&2
  local i=1
  for c in "${clusters[@]}"; do
    echo "  $i) $c" >&2
    ((i++)) || true
  done
  echo "  $i) Cancelar" >&2
  echo "" >&2

  local choice
  read -rp "Selecciona el cluster a eliminar (1-$i): " choice
  if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > i )); then
    echo "Selección no válida." >&2
    return 1
  fi
  if (( choice == i )); then
    echo "Cancelado." >&2
    return 0
  fi
  echo "${clusters[$((choice - 1))]}"
}

# --- Eliminar cluster ---
delete_cluster() {
  local name="$1"
  echo ""
  echo "Eliminando cluster '$name'..."
  kind delete cluster --name "$name"
  echo "Cluster '$name' eliminado."
}

# --- Menú principal ---
main() {
  echo "=== Kind - Gestor de clusters ==="
  echo "Carpeta de configs: $CLUSTERS_DIR"
  echo ""

  check_prerequisites

  echo "¿Qué deseas hacer?"
  echo "  1) Crear un cluster (elegir config de clusters/)"
  echo "  2) Eliminar un cluster"
  echo "  3) Salir"
  echo ""

  read -rp "Opción (1-3): " option

  case "$option" in
    1)
      CONFIG_FILE="$(select_config_file)"
      [[ -n "$CONFIG_FILE" ]] && create_cluster "$CONFIG_FILE"
      ;;
    2)
      CLUSTER_NAME="$(select_cluster_to_delete)" || true
      [[ -n "$CLUSTER_NAME" ]] && delete_cluster "$CLUSTER_NAME"
      ;;
    3)
      echo "Salir."
      exit 0
      ;;
    *)
      echo "Opción no válida."
      exit 1
      ;;
  esac
}

main "$@"
