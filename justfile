# Edgehog Development Tasks
#
# Use `just --list` to see all available tasks
# Use `just <task>` to run a specific task

set shell := ["bash", "-euo", "pipefail", "-c"]

# Default recipe to show available tasks
default:
    @just help

# Check system prerequisites
[private]
_check-system-prereqs:
    @echo "🔍 Checking system prerequisites..."
    @command -v git >/dev/null || { echo "❌ git is required"; exit 1; }
    @command -v docker >/dev/null || { echo "❌ docker is required"; exit 1; }
    @docker compose version >/dev/null || { echo "❌ docker compose is required"; exit 1; }

# Check Astarte prerequisites  
[private]
_check-astarte-prereqs:
    @echo "🔍 Checking Astarte prerequisites..."
    @command -v astartectl >/dev/null || { echo "❌ astartectl is required. Install from https://github.com/astarte-platform/astartectl"; exit 1; }

# Check Rust prerequisites for device runtime
[private]  
_check-rust-prereqs:
    @echo "🔍 Checking Rust prerequisites..."
    @command -v cargo >/dev/null || { echo "❌ cargo is required. Install Rust from https://rustup.rs/"; exit 1; }
    @command -v cc >/dev/null || { echo "❌ C compiler is required. Install build-essential or gcc"; exit 1; }

# Configure system settings for Astarte
[private]
_configure-system:
    #!/usr/bin/env bash
    aio_max_nr=$(cat /proc/sys/fs/aio-max-nr)
    if [[ "$aio_max_nr" -lt 1048576 ]]; then
        echo "🔧 Updating aio-max-nr..."
        echo "fs.aio-max-nr = 1048576" | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p
    fi

# Wait for Astarte services to be ready
[private]
_wait-astarte:
    #!/usr/bin/env bash
    echo "⏳ Waiting for Astarte services to be ready..."
    while true; do
        if curl -sf http://api.astarte.localhost/appengine/health >/dev/null && \
           curl -sf http://api.astarte.localhost/realmmanagement/health >/dev/null && \
           curl -sf http://api.astarte.localhost/pairing/health >/dev/null && \
           curl -sf http://api.astarte.localhost/housekeeping/health >/dev/null; then
            echo "✅ Astarte services are ready."
            break
        fi
        echo "⏳ Still waiting for Astarte services..."
        sleep 3
    done

# Wait for Edgehog services to be ready
[private]
_wait-edgehog:
    #!/usr/bin/env bash
    echo "⏳ Waiting for Edgehog services to be ready..."
    while true; do
        if curl -sf http://api.edgehog.localhost/admin-api/v1/swagger >/dev/null; then
            echo "✅ Edgehog services are ready."
            break
        fi
        echo "⏳ Still waiting for Edgehog services..."
        sleep 3
    done

# Initialize Astarte platform
[private]
_init-astarte:
    #!/usr/bin/env bash
    echo "🌟 Initializing Astarte..."
    if [ ! -d astarte ]; then
        git clone --depth=1 https://github.com/astarte-platform/astarte.git -b release-1.3
        ( cd astarte && echo '*' > .gitignore )
        ( cd astarte && docker run --rm --user $(id -u):$(id -g) -v "$(pwd)/compose:/compose:z" astarte/docker-compose-initializer:1.2.0 )
    fi
    ( cd astarte && docker compose pull )
    ( cd astarte && docker compose down -v )
    ( cd astarte && docker compose up -d )

# Create Astarte realm
[private]  
_create-astarte-realm:
    @echo "🏠 Creating Astarte realm..."
    astartectl housekeeping realms create test --astarte-url http://api.astarte.localhost --realm-public-key backend/priv/repo/seeds/keys/realm_public.pem -k astarte/compose/astarte-keys/housekeeping_private.pem -y

# Initialize Edgehog platform
[private]
_init-edgehog:
    @echo "🚀 Initializing Edgehog..."
    docker compose down -v
    docker compose up -d --build

# Create Edgehog tenant
[private]
_create-edgehog-tenant:
    #!/usr/bin/env bash
    admin_jwt=$(cat backend/priv/repo/seeds/keys/admin_jwt.txt)
    curl -sf -X POST "http://api.edgehog.localhost/admin-api/v1/tenants" \
         -H "Content-Type: application/vnd.api+json" \
         -H "Accept: application/vnd.api+json" \
         -H "Authorization: Bearer $admin_jwt" \
         -d '{
           "data": {
             "type": "tenant",
             "attributes": {
               "name": "Test",
               "slug": "test", 
               "default_locale": "en-US",
               "public_key": "-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhV0KI4hByk0uDkCg4yZImMTiAtz2\nazmpbh0sLAKOESdlRYOFw90Up4F9fRRV5Li6Pn5XZiMCZhVkS/PoUbIKpA==\n-----END PUBLIC KEY-----",
               "astarte_config": {
                 "base_api_url": "http://api.astarte.localhost",
                 "realm_name": "test",
                 "realm_private_key": "-----BEGIN EC PRIVATE KEY-----\nMHcCAQEEIKsJwOKgTwhzWG3tnldd71K4hef5EfjvcNroSqQDY1+5oAoGCCqGSM49\nAwEHoUQDQgAEAdBOfYfLD2ukDqgSIQyzRsLc1xEa8/ujpZFaU1/s9F/cKmvJmnOJ\nBDfpPin7DXqOng+2JsinHuhLEdP/i0InLw==\n-----END EC PRIVATE KEY-----"
               }
             }
           }
         }'

# Check if Astarte is running and start it if needed
[private]
_ensure-astarte-running:
    #!/usr/bin/env bash
    echo "🔍 Checking if Astarte is running..."
    if curl -sf http://api.astarte.localhost/appengine/health >/dev/null && \
       curl -sf http://api.astarte.localhost/realmmanagement/health >/dev/null && \
       curl -sf http://api.astarte.localhost/pairing/health >/dev/null && \
       curl -sf http://api.astarte.localhost/housekeeping/health >/dev/null; then
        echo "✅ Astarte is already running."
    else
        echo "⚠️  Astarte is not running. Starting Astarte..."
        just _check-astarte-prereqs
        just _configure-system
        just _init-astarte
        just _wait-astarte
        echo "🏠 Checking if realm exists..."
        if ! astartectl housekeeping realms list --astarte-url http://api.astarte.localhost -k astarte/compose/astarte-keys/housekeeping_private.pem | grep -q "test"; then
            echo "🏠 Realm does not exist, creating it..."
            just _create-astarte-realm
        else
            echo "✅ Realm already exists."
        fi
    fi

# Provision only Edgehog (will start Astarte if not running)
provision-edgehog: _check-system-prereqs _ensure-astarte-running _init-edgehog _wait-edgehog _create-edgehog-tenant
    @echo "🎉 Edgehog has been provisioned with the test tenant."
    @just open-dashboards

# Provision a new Edgehog tenant with Astarte backend
provision-tenant: _check-system-prereqs _check-astarte-prereqs _configure-system _init-astarte _wait-astarte _create-astarte-realm _init-edgehog _wait-edgehog _create-edgehog-tenant
    @echo "🎉 The Edgehog cluster has been provisioned and the tenant is ready."
    @just open-dashboards

# Deprovision the Edgehog tenant and clean up resources
deprovision-tenant: _check-system-prereqs && _clean-resources
    @echo "🧹 Deprovisioning Edgehog tenant..."
    @echo "🛑 Deprovisioning Edgehog..."
    docker compose down -v
    @if [ -d astarte ]; then echo "🛑 Deprovisioning Astarte..."; (cd astarte && docker compose down -v); fi
    @echo "✅ The Edgehog cluster has been deprovisioned."

# Deprovision only Edgehog and device runtime, leave Astarte running
deprovision-edgehog:
    @echo "🧹 Deprovisioning Edgehog and device runtime..."
    @echo "🛑 Stopping Edgehog services..."
    docker compose down -v
    @echo "🧹 Cleaning up device runtime files..."
    -rm -rf edgehog-device-runtime/.store/
    -rm -rf edgehog-device-runtime/.updates/
    -rm -rf edgehog-device-runtime/
    @echo "✅ Edgehog and device runtime have been deprovisioned. Astarte is still running."

# Initialize device runtime repository
[private]
_init-device-runtime:
    #!/usr/bin/env bash
    echo "🔧 Initializing Edgehog Device Runtime..."
    if [ ! -d edgehog-device-runtime ]; then
        git clone --depth=1 https://github.com/edgehog-device-manager/edgehog-device-runtime.git -b main
        ( cd edgehog-device-runtime && echo '*' > .gitignore )
    fi
    
    edgehog_device_runtime_store_directory="$(pwd)/edgehog-device-runtime/.store/"
    edgehog_device_runtime_download_directory="$(pwd)/edgehog-device-runtime/.updates/"
    rm -rf $store_directory
    rm -rf $download_directory

# Register device with Astarte and create config
[private]
_register-device:
    #!/usr/bin/env bash
    echo "📝 Registering a new device in Astarte..."
    
    device_id="$(astartectl utils device-id generate-random)"
    credentials_secret="$(astartectl pairing agent register --compact-output -r test -u http://api.astarte.localhost -k backend/priv/repo/seeds/keys/realm_private.pem -- "$device_id")"
    
    echo "⚙️ Writing Edgehog Device Runtime configuration..."
    
    cat <<EOF > edgehog-device-runtime/edgehog-config.toml
    astarte_library = "astarte-device-sdk"
    interfaces_directory = "$(pwd)/backend/priv/astarte_resources/interfaces"
    store_directory = "$(pwd)/edgehog-device-runtime/.store/"
    download_directory = "$(pwd)/edgehog-device-runtime/.updates/"
    [astarte_device_sdk]
    credentials_secret = "$credentials_secret"
    device_id = "$device_id"
    pairing_url = "http://api.astarte.localhost/pairing"
    realm = "test"
    ignore_ssl = true
    [[telemetry_config]]
    interface_name = "io.edgehog.devicemanager.SystemStatus"
    enabled = true
    period = 60
    EOF

# Connect a simulated device to the Edgehog platform
connect-device: _check-rust-prereqs _check-astarte-prereqs _init-device-runtime _register-device
    @echo "🚀 Starting Edgehog Device Runtime..."
    @echo "💡 TODO: run 'ttyd -W bash' to support Edgehog's remote terminal functionality"
    cd edgehog-device-runtime && RUST_LOG=debug cargo run --features "forwarder,containers,vendored"

# Clean up all generated files and directories
[private]
_clean-resources:
    @echo "🧹 Cleaning up generated files..."
    -rm -rf astarte/
    -rm -rf edgehog-device-runtime/.store/
    -rm -rf edgehog-device-runtime/.updates/
    -rm -rf edgehog-device-runtime/
    @echo "✅ Clean up complete."

# Show the status of running services
status:
    @echo "📊 Checking service status..."
    @echo ""
    @echo "🐳 Docker containers:"
    @-docker ps --format "{{"table {{.Names}}\t{{.Status}}\t{{.Ports}}"}}" | grep -E '^(astarte|edgehog)'
    @echo ""
    @echo "🌐 Service health checks:"
    @-echo -n "Astarte App Engine API: " && curl -sf http://api.astarte.localhost/appengine/health >/dev/null && echo "✅ OK" || echo "❌ Down"
    @-echo -n "Astarte Realm Management API: " && curl -sf http://api.astarte.localhost/realmmanagement/health >/dev/null && echo "✅ OK" || echo "❌ Down"
    @-echo -n "Astarte Pairing API: " && curl -sf http://api.astarte.localhost/pairing/health >/dev/null && echo "✅ OK" || echo "❌ Down"
    @-echo -n "Astarte Housekeeping API: " && curl -sf http://api.astarte.localhost/housekeeping/health >/dev/null && echo "✅ OK" || echo "❌ Down"
    @-echo -n "Edgehog Admin API: " && curl -sf http://api.edgehog.localhost/admin-api/v1/swagger >/dev/null && echo "✅ OK" || echo "❌ Down"

open_astarte_dashboard:
    astarte_realm_jwt=$(cat backend/priv/repo/seeds/keys/realm_jwt.txt 2>/dev/null || echo "missing")
    if [ "$astarte_realm_jwt" != "missing" ]; then
        python3 -m webbrowser "http://dashboard.astarte.localhost/auth?realm=test#access_token=$astarte_realm_jwt"
        echo "✅ Astarte dashboard opened in browser"
    else
        echo "❌ Astarte JWT token not found. Run 'just provision-tenant' first."
    fi

open_edgehog_dashboard:
    edgehog_tenant_jwt=$(cat backend/priv/repo/seeds/keys/tenant_jwt.txt 2>/dev/null || echo "missing")
    if [ "$edgehog_tenant_jwt" != "missing" ]; then
        python3 -m webbrowser "http://edgehog.localhost/login?tenantSlug=test&authToken=$edgehog_tenant_jwt"
        echo "✅ Edgehog dashboard opened in browser"
    else
        echo "❌ Edgehog JWT token not found. Run 'just provision-tenant' first."
    fi

# Open web interfaces in browser
open-dashboards:
    #!/usr/bin/env bash
    echo "🌐 Opening dashboards..."
    @-just open_astarte_dashboard
    @-just open_edgehog_dashboard

# Show logs for all services
logs:
    @echo "📋 Showing service logs..."
    docker compose logs --tail=50 -f

# Show logs for Astarte services  
logs-astarte:
    @echo "📋 Showing Astarte service logs..."
    @if [ -d astarte ]; then (cd astarte && docker compose logs --tail=50 -f); else echo "❌ Astarte not initialized"; fi

# Show available recipes with descriptions
help:
    @echo "🚀 Edgehog Development Tasks"
    @echo ""
    @echo "Main commands:"
    @echo "  provision-tenant    Set up Edgehog with Astarte backend"
    @echo "  provision-edgehog   Set up Edgehog (will start Astarte if not running)"
    @echo "  connect-device      Connect a simulated device to Edgehog"
    @echo "  deprovision-tenant  Tear down Edgehog and Astarte services"
    @echo "  deprovision-edgehog Tear down Edgehog and device runtime (keep Astarte)"
    @echo ""
    @echo "Utility commands:"
    @echo "  status              Show the status of running services"
    @echo "  logs                Show logs for all Edgehog services"
    @echo "  logs-astarte        Show logs for Astarte services"
    @echo "  open-dashboards     Open web interfaces in browser"
    @echo ""
    @echo "Use 'just <command>' to run a specific task"
