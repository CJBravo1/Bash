#!/usr/bin/env bash
#
# streaming_install.sh
#
# Builds a single "media" Docker Compose stack containing:
#   Radarr, Sonarr, Prowlarr, Plex, Jellyfin, Transmission
#
# Then wires everything together automatically:
#   - Prowlarr  -> Radarr / Sonarr   (application sync using each app's API key)
#   - Prowlarr  -> The Pirate Bay    (public indexer, synced down to Radarr/Sonarr)
#   - Radarr / Sonarr -> Transmission (download client)
#   - Radarr / Sonarr root folders    (/movies, /tv)
#   - transmission-cleanup container that deletes completed Transmission downloads every night at 12:00 AM
#
# Safe to re-run: every integration step checks whether it already exists first.
#
# Usage:
#   ./streaming_install.sh                   full install (prompts before installing Docker if missing)
#   ./streaming_install.sh --install-docker  only install Docker Engine + Compose plugin
#   ./streaming_install.sh -y                answer yes to all prompts
#   ./streaming_install.sh --volume-only     keep Radarr/Sonarr/Prowlarr/Transmission data, downloads,
#                                            movies and TV in Docker named volumes (nothing under $HOME)
#   ./streaming_install.sh --local-storage   switch back to bind mounts under $HOME (the default)
#
# The storage mode is remembered in $STACK_DIR/.env, so re-running without a flag keeps the current mode.
#
# Optional environment overrides:
#   STACK_DIR   where docker-compose.yaml + .env are written (default: ~/Docker)
#   TZ          timezone (default: system timezone, falls back to America/Chicago)
#   PLEX_CLAIM  claim token from https://plex.tv/claim (valid 4 minutes) to link Plex to your account
#   STORAGE_MODE  "local" (bind mounts under $HOME) or "volume" (Docker named volumes); same as the flags
#
set -euo pipefail

STACK_DIR="${STACK_DIR:-$HOME/Docker}"
PROJECT_NAME="media"

PUID="$(id -u)"
PGID="$(id -g)"
TZ="${TZ:-$(timedatectl show -p Timezone --value 2>/dev/null || true)}"
TZ="${TZ:-America/Chicago}"
PLEX_CLAIM="${PLEX_CLAIM:-}"
STORAGE_MODE="${STORAGE_MODE:-}"   # resolved in main(): flag > env > existing .env > "local"

# Host paths (match the existing streaming_services / transmission stacks so existing config is reused)
DATA="$HOME/Data"
MEDIA="$HOME/Movies"
DOWNLOADS="$HOME/Transmission"

RADARR_CONFIG="$DATA/radarr/config"
SONARR_CONFIG="$DATA/sonarr/data"
PROWLARR_CONFIG="$DATA/prowlarr"

# URLs used from the host (this script) and from inside the compose network (container to container)
RADARR_HOST_URL="http://localhost:7878"
SONARR_HOST_URL="http://localhost:8989"
PROWLARR_HOST_URL="http://localhost:9696"
RADARR_INTERNAL_URL="http://radarr:7878"
SONARR_INTERNAL_URL="http://sonarr:8989"
PROWLARR_INTERNAL_URL="http://prowlarr:9696"

CONTAINERS=(radarr sonarr prowlarr plex jellyfin transmission transmission-cleanup volume-init)

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m  ✗\033[0m %s\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------------------------
# 1. Prerequisites: Docker, Compose plugin, curl, jq
# --------------------------------------------------------------------------------------------

# confirm "Question?"  -> returns 0 for yes. Defaults to yes. Honors -y / ASSUME_YES=1.
confirm() {
    [[ "${ASSUME_YES:-0}" == 1 ]] && return 0
    [[ -t 0 ]] || die "$1 (no terminal to prompt on; re-run with -y to answer yes automatically)"
    local reply
    read -r -p "$(printf '\033[1;33m  ?\033[0m %s [Y/n] ' "$1")" reply
    [[ -z "$reply" || "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Install Docker Engine + Compose plugin from Docker's official repositories
install_docker() {
    . /etc/os-release
    local family=" ${ID} ${ID_LIKE:-} "

    log "Installing Docker Engine and Docker Compose plugin"

    if [[ "$family" =~ \ (fedora|rhel|centos)\  ]]; then
        local repo_os
        case "$ID" in
            fedora) repo_os=fedora ;;
            rhel)   repo_os=rhel ;;
            *)      repo_os=centos ;;   # CentOS Stream, Rocky, Alma, ...
        esac
        local repo_url="https://download.docker.com/linux/${repo_os}/docker-ce.repo"

        # Remove distro packages that conflict with docker-ce (no-op if absent)
        sudo dnf remove -y docker docker-client docker-common docker-engine \
            docker-selinux moby-engine podman-docker >/dev/null 2>&1 || true

        sudo dnf install -y dnf-plugins-core
        # dnf5 (Fedora 41+) and dnf4 use different syntax for adding a repo
        sudo dnf config-manager addrepo --overwrite --from-repofile="$repo_url" 2>/dev/null \
            || sudo dnf config-manager --add-repo "$repo_url"
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    elif [[ "$family" =~ \ (debian|ubuntu)\  ]]; then
        # Derivatives (Mint, Pop!_OS, ...) use the upstream Ubuntu/Debian repo and codename
        local repo_os codename
        if [[ "$ID" == ubuntu || "$ID" == debian ]]; then
            repo_os="$ID"
        elif [[ "$family" == *" ubuntu "* ]]; then
            repo_os=ubuntu
        else
            repo_os=debian
        fi
        if [[ "$repo_os" == ubuntu ]]; then
            codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
        else
            codename="$VERSION_CODENAME"
        fi

        sudo apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc \
            >/dev/null 2>&1 || true

        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL "https://download.docker.com/linux/${repo_os}/gpg" \
            | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${repo_os} ${codename} stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    else
        die "Unsupported distro '$ID'. Install Docker manually (https://docs.docker.com/engine/install/) and re-run."
    fi

    sudo systemctl enable --now docker

    if ! id -nG "$USER" | grep -qw docker; then
        sudo usermod -aG docker "$USER"
        warn "Added $USER to the 'docker' group. Log out and back in to run docker without sudo."
    fi

    ok "Docker installed: $(sudo docker version --format '{{.Server.Version}}'), Compose $(sudo docker compose version --short)"
}

# Install just the Compose plugin when Docker itself is already present
install_compose_plugin() {
    log "Installing Docker Compose plugin"
    if command -v dnf >/dev/null; then sudo dnf install -y docker-compose-plugin
    elif command -v apt-get >/dev/null; then sudo apt-get update && sudo apt-get install -y docker-compose-plugin
    else die "Install the Docker Compose plugin manually and re-run."; fi
}

install_prereqs() {
    log "Checking prerequisites"

    if ! command -v docker >/dev/null; then
        warn "Docker is not installed."
        confirm "Install Docker now?" || die "Docker is required. Aborting."
        install_docker
    fi

    local missing=()
    command -v curl >/dev/null || missing+=(curl)
    command -v jq   >/dev/null || missing+=(jq)
    if ((${#missing[@]})); then
        log "Installing ${missing[*]}"
        if command -v dnf >/dev/null; then sudo dnf install -y "${missing[@]}"
        elif command -v apt-get >/dev/null; then sudo apt-get install -y "${missing[@]}"
        else die "Please install: ${missing[*]}"; fi
    fi

    sudo systemctl enable --now docker

    # Use sudo for docker if the current user is not in the docker group (yet)
    if docker info >/dev/null 2>&1; then
        DOCKER=(docker)
    else
        DOCKER=(sudo docker)
        if ! id -nG "$USER" | grep -qw docker; then
            sudo usermod -aG docker "$USER"
            warn "Added $USER to the 'docker' group. Log out/in to run docker without sudo."
        fi
    fi

    if ! "${DOCKER[@]}" compose version >/dev/null 2>&1; then
        warn "Docker is installed but the Compose plugin (docker compose) is missing."
        confirm "Install the Docker Compose plugin now?" || die "Docker Compose is required. Aborting."
        install_compose_plugin
    fi

    ok "Docker $("${DOCKER[@]}" version --format '{{.Server.Version}}'), Compose $("${DOCKER[@]}" compose version --short)"
}

# --------------------------------------------------------------------------------------------
# 2. Host directories
# --------------------------------------------------------------------------------------------
create_dirs() {
    log "Creating host directories"
    # Plex and Jellyfin config always lives on the host
    mkdir -p \
        "$DATA/plex/config" "$DATA/plex/transcode" \
        "$DATA/jellyfin/config" "$DATA/jellyfin/cache" \
        "$STACK_DIR"

    if [[ "$STORAGE_MODE" == volume ]]; then
        ok "Volume-only storage: Radarr/Sonarr/Prowlarr/Transmission data, downloads, movies and TV use Docker volumes"
        return 0
    fi

    mkdir -p \
        "$RADARR_CONFIG" "$SONARR_CONFIG" "$PROWLARR_CONFIG" \
        "$DATA/transmission-hooks" \
        "$DOWNLOADS/config" "$DOWNLOADS/complete" "$DOWNLOADS/incomplete" \
        "$MEDIA/Movies" "$MEDIA/TV Shows"
    ok "Directories ready under $DATA, $MEDIA, $DOWNLOADS"
}

# --------------------------------------------------------------------------------------------
# 3. Combined compose file
# --------------------------------------------------------------------------------------------

# Fill the @PLACEHOLDER@ storage slots in the compose template for the chosen STORAGE_MODE.
#   local:  bind mounts under $HOME (the original layout)
#   volume: Docker named volumes (media_movies, media_tv, ...), nothing written under $HOME for
#           Radarr/Sonarr/Prowlarr/Transmission. A one-shot volume-init container gives the media and
#           download volumes to PUID:PGID before the apps start, since new volumes are owned by root.
render_storage() {
    local c="$1" key
    local -A src
    local init_dep="" init_svc="" vols=$'\n'

    if [[ "$STORAGE_MODE" == volume ]]; then
        src=(
            [RADARR_CONFIG]=radarr-config  [SONARR_CONFIG]=sonarr-config  [PROWLARR_CONFIG]=prowlarr-config
            [TRANSMISSION_CONFIG]=transmission-config  [TRANSMISSION_HOOKS]=transmission-hooks
            [DOWNLOADS]=downloads  [MOVIES]=movies  [TV]=tv
        )
        init_dep=$'\n    depends_on:\n      volume-init:\n        condition: service_completed_successfully'
        init_svc=$'\n  # Volume-only storage: new named volumes are owned by root, so hand them to PUID:PGID once\n  volume-init:\n    image: alpine:3.20\n    container_name: volume-init\n    command: ["chown", "${PUID}:${PGID}", "/movies", "/tv", "/downloads", "/hooks"]\n    volumes:\n      - "movies:/movies"\n      - "tv:/tv"\n      - "downloads:/downloads"\n      - "transmission-hooks:/hooks"\n    restart: "no"\n'
        vols=$'\n# Volume-only storage. "docker compose down -v" DELETES these, including all movies and TV.\nvolumes:\n  radarr-config:\n  sonarr-config:\n  prowlarr-config:\n  transmission-config:\n  transmission-hooks:\n  downloads:\n  movies:\n  tv:\n'
    else
        src=(
            [RADARR_CONFIG]='${HOME}/Data/radarr/config'  [SONARR_CONFIG]='${HOME}/Data/sonarr/data'
            [PROWLARR_CONFIG]='${HOME}/Data/prowlarr'  [TRANSMISSION_CONFIG]='${HOME}/Transmission/config'
            [TRANSMISSION_HOOKS]='${HOME}/Data/transmission-hooks'  [DOWNLOADS]='${HOME}/Transmission'
            [MOVIES]='${HOME}/Movies/Movies'  [TV]='${HOME}/Movies/TV Shows'
        )
    fi

    for key in "${!src[@]}"; do
        c="${c//"@${key}@"/"${src[$key]}"}"
    done
    c="${c//"@INIT_DEP@"/"$init_dep"}"
    c="${c//$'\n'"@VOLUME_INIT@"/"$init_svc"}"
    c="${c//$'\n'"@VOLUMES@"/"$vols"}"
    printf '%s' "$c"
}
write_compose() {
    log "Writing combined stack to $STACK_DIR"

    cat >"$STACK_DIR/.env" <<EOF
PUID=$PUID
PGID=$PGID
TZ=$TZ
PLEX_CLAIM=$PLEX_CLAIM
STORAGE_MODE=$STORAGE_MODE
EOF

    local compose="$STACK_DIR/docker-compose.yaml"
    local tmp
    tmp="$(mktemp)"

    # Quoted heredoc: ${PUID}/${TZ}/... are resolved by docker compose from .env; ${HOME} is replaced below.
    cat >"$tmp" <<'EOF'
# Generated by streaming_install.sh. Combined media stack.
# All services except Plex share the default "media_default" network and reach each other by
# service name (e.g. http://radarr:7878). Plex uses host networking for LAN discovery/DLNA.
name: media

services:
@VOLUME_INIT@
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - "@RADARR_CONFIG@:/config"
      - "@MOVIES@:/movies"
      - "@DOWNLOADS@:/downloads"
    ports:
      - "7878:7878"@INIT_DEP@
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - "@SONARR_CONFIG@:/config"
      - "@TV@:/tv"
      - "@DOWNLOADS@:/downloads"
    ports:
      - "8989:8989"@INIT_DEP@
    restart: unless-stopped

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - "@PROWLARR_CONFIG@:/config"
    ports:
      - "9696:9696"
    restart: unless-stopped

  transmission:
    image: lscr.io/linuxserver/transmission:latest
    container_name: transmission
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - "@TRANSMISSION_CONFIG@:/config"
      - "@DOWNLOADS@:/downloads"
      - "@TRANSMISSION_HOOKS@:/hooks"
    ports:
      - "9091:9091"
      - "51413:51413"
      - "51413:51413/udp"@INIT_DEP@
    restart: unless-stopped

  # Nightly cleanup: at 12:00 AM (TZ above), removes every 100%-complete torrent from Transmission
  # AND deletes its files. Runs entirely in this container; nothing is installed on the host.
  # The script itself is the "transmission-cleanup" config at the bottom of this file.
  transmission-cleanup:
    image: alpine:3.20
    container_name: transmission-cleanup
    depends_on:
      - transmission
    environment:
      - TZ=${TZ}
      - RPC_URL=http://transmission:9091/transmission/rpc
    configs:
      - source: transmission-cleanup
        target: /cleanup.sh
    command:
      - sh
      - -c
      - |
        apk add --no-cache curl jq tzdata >/dev/null
        echo '0 0 * * * sh /cleanup.sh > /proc/1/fd/1 2>&1' > /etc/crontabs/root
        exec crond -f -l 8
    restart: unless-stopped

  plex:
    image: lscr.io/linuxserver/plex:latest
    container_name: plex
    network_mode: host
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - VERSION=docker
      - PLEX_CLAIM=${PLEX_CLAIM}
    volumes:
      - "${HOME}/Data/plex/config:/config"
      - "${HOME}/Data/plex/transcode:/transcode"
      - "@MOVIES@:/movies"
      - "@TV@:/tv"@INIT_DEP@
    restart: unless-stopped

  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - "${HOME}/Data/jellyfin/config:/config"
      - "${HOME}/Data/jellyfin/cache:/cache"
      - "@MOVIES@:/data/movies"
      - "@TV@:/data/tv"
    ports:
      - "8096:8096"@INIT_DEP@
    restart: unless-stopped
@VOLUMES@
configs:
  # POSIX sh (busybox). "$$" is how a literal "$" is written inside a compose file.
  transmission-cleanup:
    content: |
      #!/bin/sh
      # Removes every 100%-complete torrent from Transmission AND deletes its downloaded files.
      # Incomplete downloads are left alone.
      set -eu

      log() { echo "$$(date '+%F %T') $$*"; }

      # Transmission requires a session id, which it hands out on a 409 response
      SESSION_ID="$$(curl -s -o /dev/null -D - "$$RPC_URL" | tr -d '\r' \
          | awk 'tolower($$1) == "x-transmission-session-id:" { print $$2 }')"
      [ -n "$$SESSION_ID" ] || { log "Transmission RPC not reachable at $$RPC_URL" >&2; exit 1; }

      rpc() {
          curl -fsS -H "X-Transmission-Session-Id: $$SESSION_ID" \
              -H 'Content-Type: application/json' --data-binary "$$1" "$$RPC_URL"
      }

      completed="$$(rpc '{"method":"torrent-get","arguments":{"fields":["id","name","percentDone","sizeWhenDone"]}}' \
          | jq -c '[.arguments.torrents[] | select(.percentDone == 1 and .sizeWhenDone > 0)]')"

      count="$$(printf '%s' "$$completed" | jq length)"
      if [ "$$count" -eq 0 ]; then
          log "No completed downloads to remove."
          exit 0
      fi

      printf '%s' "$$completed" | jq -r '.[].name' | while IFS= read -r name; do log "Removing: $$name"; done
      rpc "$$(printf '%s' "$$completed" | jq -c '{method: "torrent-remove", arguments: {ids: [.[].id], "delete-local-data": true}}')" \
          | jq -e '.result == "success"' >/dev/null
      log "Removed $$count completed download(s)."
EOF

    local content
    content="$(<"$tmp")"
    content="$(render_storage "$content")"
    # Bake in absolute host paths: if docker ends up running via sudo, $HOME would be /root.
    printf '%s\n' "${content//'${HOME}'/$HOME}" >"$tmp"

    if [[ -f "$compose" ]] && ! cmp -s "$tmp" "$compose"; then
        local backup
        backup="$compose.bak.$(date +%Y%m%d%H%M%S)"
        cp "$compose" "$backup"
        warn "Existing compose file differed; backed up to $backup"
    fi
    mv "$tmp" "$compose"
    ok "docker-compose.yaml written"
}

# --------------------------------------------------------------------------------------------
# 4. Start the stack
# --------------------------------------------------------------------------------------------
start_stack() {
    log "Starting stack"

    # Containers from the old separate stacks (streaming_services, transmission) use the same
    # container_name values and would block startup. Their config lives in bind mounts, so
    # removing the containers loses nothing.
    local name project
    for name in "${CONTAINERS[@]}"; do
        project="$("${DOCKER[@]}" inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$name" 2>/dev/null || true)"
        if "${DOCKER[@]}" inspect "$name" >/dev/null 2>&1 && [[ "$project" != "$PROJECT_NAME" ]]; then
            warn "Removing old '$name' container (project: ${project:-none}); config on disk is kept"
            "${DOCKER[@]}" rm -f "$name" >/dev/null
        fi
    done

    "${DOCKER[@]}" compose -f "$STACK_DIR/docker-compose.yaml" --env-file "$STACK_DIR/.env" pull
    "${DOCKER[@]}" compose -f "$STACK_DIR/docker-compose.yaml" --env-file "$STACK_DIR/.env" up -d
    ok "Containers started"
}

# --------------------------------------------------------------------------------------------
# 5. Integration helpers
# --------------------------------------------------------------------------------------------

# Wait for an *arr config.xml to contain an API key, then print it.
# Reads the host copy in local mode, or from inside the container in volume mode.
get_api_key() {
    local config="$1/config.xml" app="$2" container="$3" key="" i
    for ((i = 0; i < 90; i++)); do
        if [[ "$STORAGE_MODE" == volume ]]; then
            key="$("${DOCKER[@]}" exec "$container" cat /config/config.xml 2>/dev/null \
                | sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' || true)"
        elif [[ -r "$config" ]]; then
            key="$(sed -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' "$config")"
        fi
        [[ -n "$key" ]] && { echo "$key"; return 0; }
        sleep 2
    done
    die "Timed out waiting for $app API key"
}

# Wait until an *arr API answers with a valid key
wait_for_api() {
    local url="$1" key="$2" app="$3" ver="$4" i
    for ((i = 0; i < 90; i++)); do
        if curl -fsS -o /dev/null -H "X-Api-Key: $key" "$url/api/$ver/system/status" 2>/dev/null; then
            ok "$app API is up"
            return 0
        fi
        sleep 2
    done
    die "$app did not become ready at $url"
}

# api METHOD URL KEY [JSON_BODY]  -> prints response body, fails on HTTP >= 400
api() {
    local method="$1" url="$2" key="$3" body="${4:-}" resp code
    if [[ -n "$body" ]]; then
        resp="$(curl -sS -w '\n%{http_code}' -X "$method" -H "X-Api-Key: $key" \
            -H 'Content-Type: application/json' --data-binary "$body" "$url")"
    else
        resp="$(curl -sS -w '\n%{http_code}' -X "$method" -H "X-Api-Key: $key" "$url")"
    fi
    code="${resp##*$'\n'}"
    resp="${resp%$'\n'*}"
    if ((code >= 400)); then
        printf '%s\n' "$resp" >&2
        return 1
    fi
    printf '%s\n' "$resp"
}

# Add an application (Radarr/Sonarr) to Prowlarr
prowlarr_add_app() {
    local impl="$1" app_internal_url="$2" app_key="$3"

    if api GET "$PROWLARR_HOST_URL/api/v1/applications" "$PROWLARR_KEY" \
        | jq -e --arg i "$impl" 'any(.[]; .implementation == $i)' >/dev/null; then
        ok "Prowlarr -> $impl already configured"
        return 0
    fi

    local body
    body="$(api GET "$PROWLARR_HOST_URL/api/v1/applications/schema" "$PROWLARR_KEY" | jq \
        --arg i "$impl" --arg p "$PROWLARR_INTERNAL_URL" --arg b "$app_internal_url" --arg k "$app_key" '
        first(.[] | select(.implementation == $i))
        | .name = $i
        | .syncLevel = "fullSync"
        | .fields |= map(
            if   .name == "prowlarrUrl" then .value = $p
            elif .name == "baseUrl"     then .value = $b
            elif .name == "apiKey"      then .value = $k
            else . end)')"

    api POST "$PROWLARR_HOST_URL/api/v1/applications" "$PROWLARR_KEY" "$body" >/dev/null \
        || die "Failed to add $impl to Prowlarr"
    ok "Prowlarr -> $impl linked (full sync)"
}

# Add The Pirate Bay indexer to Prowlarr
prowlarr_add_tpb() {
    if api GET "$PROWLARR_HOST_URL/api/v1/indexer" "$PROWLARR_KEY" \
        | jq -e 'any(.[]; .definitionName == "thepiratebay")' >/dev/null; then
        ok "The Pirate Bay indexer already present"
        return 0
    fi

    # Indexer definitions are downloaded on first boot, so retry until TPB shows up in the schema
    local schema="" profile i
    for ((i = 0; i < 30; i++)); do
        schema="$(api GET "$PROWLARR_HOST_URL/api/v1/indexer/schema" "$PROWLARR_KEY" \
            | jq 'first(.[] | select(.definitionName == "thepiratebay")) // empty')" || true
        [[ -n "$schema" ]] && break
        sleep 5
    done
    [[ -n "$schema" ]] || die "The Pirate Bay definition not found in Prowlarr indexer schema"

    profile="$(api GET "$PROWLARR_HOST_URL/api/v1/appprofile" "$PROWLARR_KEY" | jq '.[0].id // 1')"

    local body
    body="$(jq --argjson p "$profile" '
        .name = "The Pirate Bay"
        | .enable = true
        | .appProfileId = $p
        | .priority = 25' <<<"$schema")"

    if api POST "$PROWLARR_HOST_URL/api/v1/indexer" "$PROWLARR_KEY" "$body" >/dev/null 2>&1; then
        ok "The Pirate Bay indexer added"
    elif api POST "$PROWLARR_HOST_URL/api/v1/indexer?forceSave=true" "$PROWLARR_KEY" "$body" >/dev/null; then
        warn "The Pirate Bay added, but Prowlarr's connection test failed (site may be blocked by your ISP/DNS)"
    else
        die "Failed to add The Pirate Bay indexer"
    fi
}

# Add Transmission as the download client in Radarr/Sonarr
arr_add_transmission() {
    local app="$1" url="$2" key="$3"

    if api GET "$url/api/v3/downloadclient" "$key" \
        | jq -e 'any(.[]; .implementation == "Transmission")' >/dev/null; then
        ok "$app -> Transmission already configured"
        return 0
    fi

    local body
    body="$(api GET "$url/api/v3/downloadclient/schema" "$key" | jq '
        first(.[] | select(.implementation == "Transmission"))
        | .name = "Transmission"
        | .enable = true
        | .fields |= map(
            if   .name == "host" then .value = "transmission"
            elif .name == "port" then .value = 9091
            else . end)')"

    api POST "$url/api/v3/downloadclient" "$key" "$body" >/dev/null \
        || die "Failed to add Transmission to $app"
    ok "$app -> Transmission linked"
}

# Add a root folder to Radarr/Sonarr
arr_add_rootfolder() {
    local app="$1" url="$2" key="$3" path="$4"

    if api GET "$url/api/v3/rootfolder" "$key" \
        | jq -e --arg p "$path" 'any(.[]; .path == $p or .path == ($p + "/"))' >/dev/null; then
        ok "$app root folder $path already present"
        return 0
    fi
    api POST "$url/api/v3/rootfolder" "$key" "$(jq -n --arg p "$path" '{path: $p}')" >/dev/null \
        || die "Failed to add root folder $path to $app"
    ok "$app root folder $path added"
}

# --------------------------------------------------------------------------------------------
# 6. Wire everything together
# --------------------------------------------------------------------------------------------
configure_integrations() {
    log "Reading API keys"
    RADARR_KEY="$(get_api_key "$RADARR_CONFIG" Radarr radarr)"
    SONARR_KEY="$(get_api_key "$SONARR_CONFIG" Sonarr sonarr)"
    PROWLARR_KEY="$(get_api_key "$PROWLARR_CONFIG" Prowlarr prowlarr)"
    ok "API keys found for Radarr, Sonarr, Prowlarr"

    log "Waiting for services"
    wait_for_api "$RADARR_HOST_URL"   "$RADARR_KEY"   Radarr   v3
    wait_for_api "$SONARR_HOST_URL"   "$SONARR_KEY"   Sonarr   v3
    wait_for_api "$PROWLARR_HOST_URL" "$PROWLARR_KEY" Prowlarr v1

    log "Configuring Radarr / Sonarr"
    arr_add_transmission Radarr "$RADARR_HOST_URL" "$RADARR_KEY"
    arr_add_transmission Sonarr "$SONARR_HOST_URL" "$SONARR_KEY"
    arr_add_rootfolder Radarr "$RADARR_HOST_URL" "$RADARR_KEY" /movies
    arr_add_rootfolder Sonarr "$SONARR_HOST_URL" "$SONARR_KEY" /tv

    log "Configuring Prowlarr"
    prowlarr_add_app Radarr "$RADARR_INTERNAL_URL" "$RADARR_KEY"
    prowlarr_add_app Sonarr "$SONARR_INTERNAL_URL" "$SONARR_KEY"
    prowlarr_add_tpb

    # Push indexers down to Radarr/Sonarr now instead of waiting for the scheduled sync
    api POST "$PROWLARR_HOST_URL/api/v1/command" "$PROWLARR_KEY" '{"name":"ApplicationIndexerSync"}' >/dev/null \
        && ok "Triggered Prowlarr indexer sync to Radarr/Sonarr"
}

# --------------------------------------------------------------------------------------------
# 7. Remove the old host-side cleanup (systemd timer) if an earlier version of this script
#    installed it. Cleanup now runs in the transmission-cleanup container instead.
# --------------------------------------------------------------------------------------------
remove_host_cleanup_timer() {
    [[ -e /etc/systemd/system/transmission-cleanup.timer \
        || -e /etc/systemd/system/transmission-cleanup.service \
        || -e /usr/local/bin/transmission-cleanup ]] || return 0

    log "Removing old host transmission-cleanup timer (now handled by the transmission-cleanup container)"
    sudo systemctl disable --now transmission-cleanup.timer 2>/dev/null || true
    sudo rm -f /etc/systemd/system/transmission-cleanup.timer \
        /etc/systemd/system/transmission-cleanup.service \
        /usr/local/bin/transmission-cleanup
    sudo systemctl daemon-reload
    ok "Host timer removed"
}

summary() {
    local ip
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    ip="${ip:-localhost}"
    cat <<EOF

$(printf '\033[1;32m')Media stack is up.$(printf '\033[0m')  Compose file: $STACK_DIR/docker-compose.yaml

  Radarr        http://$ip:7878
  Sonarr        http://$ip:8989
  Prowlarr      http://$ip:9696
  Transmission  http://$ip:9091
  Jellyfin      http://$ip:8096        (finish the setup wizard; libraries are under /data/*)
  Plex          http://$ip:32400/web   (libraries: /movies, /tv)

Next steps:
  - Radarr/Sonarr/Prowlarr will ask you to set a login the first time you open them.
  - Manage the stack with:  docker compose -f "$STACK_DIR/docker-compose.yaml" [ps|logs|down|pull]
  - Completed Transmission downloads are deleted nightly at 12:00 AM by the transmission-cleanup container.
      Run now:   docker exec transmission-cleanup sh /cleanup.sh
      Logs:      docker logs transmission-cleanup
      Disable:   docker compose -f "$STACK_DIR/docker-compose.yaml" stop transmission-cleanup
EOF
    if [[ "$STORAGE_MODE" == volume ]]; then
        cat <<EOF

Storage: VOLUME-ONLY. Radarr/Sonarr/Prowlarr/Transmission data, downloads, movies and TV live in
Docker volumes (docker volume ls --filter name=media_), not under $HOME.
Plex and Jellyfin config are still under $DATA.
  WARNING: "docker compose down -v" or "docker volume prune" deletes the volumes, including every movie and show.
EOF
    fi
}

# Pick the storage mode: flag/env if given, otherwise whatever the last run used, otherwise local.
# Switching modes does not move data, so warn and confirm.
resolve_storage_mode() {
    local previous=""
    [[ -r "$STACK_DIR/.env" ]] && previous="$(sed -n 's/^STORAGE_MODE=//p' "$STACK_DIR/.env")"
    STORAGE_MODE="${STORAGE_MODE:-${previous:-local}}"

    case "$STORAGE_MODE" in
        local|volume) ;;
        *) die "STORAGE_MODE must be 'local' or 'volume' (got '$STORAGE_MODE')" ;;
    esac

    # Stacks from before this option existed have no STORAGE_MODE line and were local
    if [[ -f "$STACK_DIR/docker-compose.yaml" && "${previous:-local}" != "$STORAGE_MODE" ]]; then
        warn "Switching storage from '${previous:-local}' to '$STORAGE_MODE'. Existing data is NOT copied over:"
        warn "Radarr/Sonarr/Prowlarr/Transmission start fresh, and movies/TV from the old location won't be visible."
        confirm "Continue with $STORAGE_MODE storage?" || die "Aborted."
    fi
    log "Storage mode: $STORAGE_MODE"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

  (no options)      Install Docker if needed (asks first), then build and configure the media stack
  --install-docker  Only install Docker Engine + Compose plugin, then exit
  -y, --yes         Answer yes to all prompts (non-interactive)
  --volume-only     Store Radarr/Sonarr/Prowlarr/Transmission data, downloads, movies and TV in Docker
                    named volumes instead of under \$HOME (remembered for future runs)
  --local-storage   Store everything under \$HOME with bind mounts (the default)
  -h, --help        Show this help
EOF
}

main() {
    local docker_only=0
    while (($#)); do
        case "$1" in
            --install-docker) docker_only=1 ;;
            -y|--yes)         ASSUME_YES=1 ;;
            --volume-only)    STORAGE_MODE=volume ;;
            --local-storage)  STORAGE_MODE=local ;;
            -h|--help)        usage; exit 0 ;;
            *)                usage >&2; die "Unknown option: $1" ;;
        esac
        shift
    done

    if ((docker_only)); then
        if command -v docker >/dev/null && sudo docker compose version >/dev/null 2>&1; then
            ok "Docker is already installed: $(sudo docker version --format '{{.Server.Version}}'), Compose $(sudo docker compose version --short)"
        elif command -v docker >/dev/null; then
            install_compose_plugin
        else
            install_docker
        fi
        exit 0
    fi

    resolve_storage_mode
    install_prereqs
    create_dirs
    write_compose
    start_stack
    configure_integrations
    remove_host_cleanup_timer
    summary
}

main "$@"
