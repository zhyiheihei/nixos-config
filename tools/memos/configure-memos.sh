#!/usr/bin/env bash
# Configure Memos 0.29.1 through its official HTTP/Connect APIs.
# This script never touches the Memos database directly.
set -euo pipefail

BASE="${MEMOS_BASE_URL:-http://127.0.0.1:13819}"
CONNECT="${BASE}"
TOKEN="${MEMOS_ADMIN_TOKEN:-}"

if [[ -z "${TOKEN}" && -n "${MEMOS_ADMIN_TOKEN_FILE:-}" && -r "${MEMOS_ADMIN_TOKEN_FILE}" ]]; then
  TOKEN="$(cat "${MEMOS_ADMIN_TOKEN_FILE}")"
fi

if [[ -z "${TOKEN}" ]]; then
  echo "MEMOS_ADMIN_TOKEN or MEMOS_ADMIN_TOKEN_FILE is required: create a Personal Access Token in Memos Settings > Access Tokens" >&2
  exit 1
fi

read_secret() {
  local var="$1"
  local file="${2:-}"
  local value="${!var:-}"
  if [[ -n "${value}" ]]; then
    printf '%s' "${value}"
    return
  fi
  if [[ -z "${file}" || ! -r "${file}" ]]; then
    echo "missing secret for ${var}: set ${var} or provide ${file}" >&2
    exit 1
  fi
  cat "${file}"
}

DEX_MEMOS_SECRET="$(read_secret DEX_MEMOS_SECRET "${DEX_MEMOS_SECRET_FILE:-/run/secrets/dex-memos-secret}")"
METAPI_API_KEY="$(read_secret METAPI_API_KEY "${METAPI_API_KEY_FILE:-/run/secrets/memos-metapi-key}")"
SMTP_PASSWORD="$(read_secret SMTP_PASSWORD "${SMTP_PASSWORD_FILE:-/run/secrets/smtp-pass}")"

AUTH=(-H "Authorization: Bearer ${TOKEN}")
JSON=(-H "Content-Type: application/json")

rest_get() {
  curl -fsS --retry 3 "${AUTH[@]}" "${BASE}${1}"
}

connect_call() {
  local body
  body="$(curl -fsS --retry 3 "${AUTH[@]}" "${JSON[@]}" -X POST --data "${2}" "${CONNECT}/memos.api.v1.${1}")"
  if [[ -n "$(jq -r '.code // empty' <<<"${body}" 2>/dev/null || true)" ]]; then
    echo "API error for ${1}: $(jq -c '{code,message}' <<<"${body}")" >&2
    return 1
  fi
  printf '%s' "${body}"
}

echo "Configuring Dex OIDC identity provider through the official API"
IDP_JSON="$(
  jq -nc \
    --arg clientSecret "${DEX_MEMOS_SECRET}" \
    '{
      title: "Dex",
      identifierFilter: "^zhyi$",
      type: "OAUTH2",
      config: {
        oauth2Config: {
          clientId: "memos",
          clientSecret: $clientSecret,
          authUrl: "https://login.zhyi.xin/auth",
          tokenUrl: "https://login.zhyi.xin/token",
          userInfoUrl: "https://login.zhyi.xin/userinfo",
          scopes: ["openid", "profile", "email", "groups"],
          fieldMapping: {
            identifier: "preferred_username",
            displayName: "name",
            email: "email"
          }
        }
      }
    }'
)"
if rest_get "/api/v1/identity-providers" | jq -e '.identityProviders[] | select(.name == "identity-providers/dex-memos")' >/dev/null; then
  connect_call IdentityProviderService/UpdateIdentityProvider \
    "$(jq -nc --argjson idp "${IDP_JSON}" '{identityProvider: ($idp + {name:"identity-providers/dex-memos"}), updateMask:"title,identifierFilter,config"}')" >/dev/null
else
  connect_call IdentityProviderService/CreateIdentityProvider \
    "$(jq -nc --arg id "dex-memos" --argjson idp "${IDP_JSON}" '{identityProviderId:$id, identityProvider:$idp}')" >/dev/null
fi

echo "Configuring AI provider through Metapi through the official API"
AI_JSON="$(
  jq -nc \
    --arg apiKey "${METAPI_API_KEY}" \
    '{
      name: "instance/settings/AI",
      aiSetting: {
        providers: [
          {
            id: "metapi",
            title: "Metapi",
            type: "OPENAI",
            endpoint: "https://metapi.colocrossing.zhyi.cc/v1",
            apiKey: $apiKey
          }
        ]
      }
    }'
)"
connect_call InstanceService/UpdateInstanceSetting \
  "$(jq -nc --argjson setting "${AI_JSON}" '{setting:$setting}')" >/dev/null

echo "Configuring email notifications through the existing SMTP transport via the official API"
NOTIFICATION_JSON="$(
  jq -nc \
    --arg smtpPassword "${SMTP_PASSWORD}" \
    '{
      name: "instance/settings/NOTIFICATION",
      notificationSetting: {
        email: {
          enabled: true,
          smtpHost: "send.ahasend.com",
          smtpPort: 587,
          smtpUsername: "EjG9ROGAei",
          smtpPassword: $smtpPassword,
          fromEmail: "postmaster@zhyi.cc",
          fromName: "Memos",
          replyTo: "",
          useTls: true,
          useSsl: false
        }
      }
    }'
)"
connect_call InstanceService/UpdateInstanceSetting \
  "$(jq -nc --argjson setting "${NOTIFICATION_JSON}" '{setting:$setting}')" >/dev/null

echo "Configuring local attachment storage through the official API"
STORAGE_JSON="$(
  jq -nc \
    '{
      name: "instance/settings/STORAGE",
      storageSetting: {
        storageType: "LOCAL",
        filepathTemplate: "assets/{timestamp}_{filename}",
        uploadSizeLimitMb: 64
      }
    }'
)"
connect_call InstanceService/UpdateInstanceSetting \
  "$(jq -nc --argjson setting "${STORAGE_JSON}" '{setting:$setting}')" >/dev/null

echo "Verifying applied settings"
rest_get "/api/v1/identity-providers/dex-memos" |
  jq '{name, title, identifierFilter, clientId: .config.oauth2Config.clientId, endpoints: [.config.oauth2Config.authUrl, .config.oauth2Config.tokenUrl, .config.oauth2Config.userInfoUrl]}'
rest_get "/api/v1/instance/settings/AI" |
  jq '{name, providers: [.aiSetting.providers[] | {id, title, type, endpoint, apiKeySet}]}'
rest_get "/api/v1/instance/settings/NOTIFICATION" |
  jq '{name, emailEnabled: .notificationSetting.email.enabled, smtpHost: .notificationSetting.email.smtpHost, fromEmail: .notificationSetting.email.fromEmail}'
rest_get "/api/v1/instance/settings/STORAGE" |
  jq '{name, storageType: .storageSetting.storageType, filepathTemplate: .storageSetting.filepathTemplate, uploadSizeLimitMb: .storageSetting.uploadSizeLimitMb}'
