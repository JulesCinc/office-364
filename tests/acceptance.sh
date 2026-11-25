#!/usr/bin/env bash
# Script d'acceptation de l'étape 1 (#8, spec #9).
#
# Démarre la pile Compose avec la surcharge de test sur des volumes vierges,
# puis vérifie de l'extérieur, comme le verraient l'Administrateur, un
# Enseignant ou un Élève, les critères de fin de #8.
#
# Dépendances : Docker (avec Compose >= 2.24.4), curl et jq. Si jq n'est pas
# installé, l'image Docker officielle de jq est utilisée à la place.
#
# Usage : tests/acceptance.sh
# Variables facultatives :
#   ACCEPTANCE_PROJECT  nom du projet Compose de test (défaut : office364-acceptance)
#   TEST_HTTP_PORT      port HTTP publié sur 127.0.0.1 (défaut : 18080)
#   ACCEPTANCE_KEEP=1   ne supprime pas la pile à la fin (pour déboguer)
set -euo pipefail

# Git Bash (Windows) convertit les arguments qui commencent par « / » en
# chemins Windows ; on désactive cette conversion pour les appels à docker.
export MSYS_NO_PATHCONV=1

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

PROJECT="${ACCEPTANCE_PROJECT:-office364-acceptance}"
export TEST_HTTP_PORT="${TEST_HTTP_PORT:-18080}"
BASE_URL="http://localhost:${TEST_HTTP_PORT}"
JQ_IMAGE="ghcr.io/jqlang/jq:1.7.1"

# Groupes attendus, en identifiants percent-encodés pour les URL.
GROUP_ELEVES="Élèves"
GROUP_ENSEIGNANTS="Enseignants"
GROUP_ELEVES_URL="%C3%89l%C3%A8ves"

WORK_DIR="$(mktemp -d)"
PASSED=0
FAILED=0

# --- Outils -----------------------------------------------------------------

log() { printf '\n==> %s\n' "$*"; }
pass() { PASSED=$((PASSED + 1)); printf '  [OK]    %s\n' "$*"; }
fail() { FAILED=$((FAILED + 1)); printf '  [ÉCHEC] %s\n' "$*"; }
die() { printf '\n[ERREUR] %s\n' "$*" >&2; exit 1; }

# check "description" commande... : enregistre un succès ou un échec.
check() {
  local description="$1"; shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

jq() {
  if command -v jq >/dev/null 2>&1; then
    command jq "$@"
  else
    docker run --rm -i "$JQ_IMAGE" "$@"
  fi
}

compose() {
  docker compose -p "$PROJECT" -f docker-compose.yml -f docker-compose.test.yml "$@"
}

occ() {
  compose exec -T -u www-data nextcloud php occ "$@"
}

# Valeur d'une variable dans un fichier d'environnement (sans l'interpréter).
env_value() {
  sed -n "s/^$2=//p" "$1" | tail -n 1 | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

# Requête HTTP : http_code MÉTHODE URL IDENTIFIANT MOT_DE_PASSE [options curl...]
# Écrit le corps dans $WORK_DIR/body et affiche le code HTTP.
http_code() {
  local method="$1" url="$2" user="$3" password="$4"; shift 4
  curl -s -o "$WORK_DIR/body" -w '%{http_code}' -X "$method" \
    -u "$user:$password" -H 'OCS-APIRequest: true' "$@" "$url" || true
}

# Requête OCS en JSON : ocs MÉTHODE CHEMIN IDENTIFIANT MOT_DE_PASSE [options curl...]
# Affiche le corps de la réponse.
ocs() {
  local method="$1" path="$2" user="$3" password="$4"; shift 4
  local separator='?'
  case "$path" in *\?*) separator='&' ;; esac
  http_code "$method" "${BASE_URL}/ocs/v2.php/${path}${separator}format=json" \
    "$user" "$password" "$@" >/dev/null
  cat "$WORK_DIR/body"
}

random_password() {
  # 24 caractères alphanumériques, plus un suffixe pour la politique de mots de passe.
  printf '%s-Aa1!' "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)"
}

wait_installed() {
  local deadline=$((SECONDS + ${1:-600}))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if curl -sf "${BASE_URL}/status.php" 2>/dev/null | jq -e '.installed == true' >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done
  return 1
}

cleanup() {
  local status=$?
  rm -rf "$WORK_DIR"
  if [ "${ACCEPTANCE_KEEP:-0}" = "1" ]; then
    log "Pile de test conservée (ACCEPTANCE_KEEP=1) : projet ${PROJECT}"
  else
    log "11. Suppression de la pile et des volumes de test"
    compose down -v --remove-orphans >/dev/null 2>&1 || true
  fi
  exit "$status"
}

# --- Garde-fous sur .env ----------------------------------------------------

[ -f .env ] || die ".env est absent : copiez .env.example en .env et remplissez-le."
for variable in MYSQL_ROOT_PASSWORD MYSQL_PASSWORD NEXTCLOUD_ADMIN_PASSWORD REDIS_HOST_PASSWORD; do
  value="$(env_value .env "$variable")"
  [ -n "$value" ] || die "$variable est vide dans .env."
  [ "$value" != "$(env_value .env.example "$variable")" ] \
    || die "$variable a encore sa valeur d'exemple dans .env : choisissez un vrai mot de passe."
done
ADMIN_USER="$(env_value .env NEXTCLOUD_ADMIN_USER)"
ADMIN_PASSWORD="$(env_value .env NEXTCLOUD_ADMIN_PASSWORD)"

trap cleanup EXIT

# --- 1. Démarrage sur des volumes vierges -----------------------------------

log "1. Démarrage de la pile de test (projet ${PROJECT}) sur des volumes vierges"
compose down -v --remove-orphans >/dev/null 2>&1 || true
compose up -d
check "Nextcloud est installé (status.php : installed = true)" wait_installed 900

printf '\nRésultat : %d vérification(s) réussie(s), %d en échec.\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
