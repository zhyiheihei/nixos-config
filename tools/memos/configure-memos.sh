#!/usr/bin/env bash
# Configure Memos 0.29.1 through its official HTTP/Connect APIs.
# This script never touches the Memos database directly.
set -euo pipefail

BASE="${MEMOS_BASE_URL:-http://127.0.0.1:13819}"
CONNECT="${BASE}/memos.api.v1"
TOKEN="${MEMOS_ADMIN_TOKEN:-}"

if [[ -z "${TOKEN}" ]]; then
  echo "MEMOS_ADMIN_TOKEN is required: create a Personal Access Token in Memos Settings > Access Tokens" >&2
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
  curl -fsS --retry 3 "${AUTH[@]}" "${JSON[@]}" -X POST --data "${2}" "${CONNECT}/${1}"
}

echo "Configuring Dex OIDC identity provider through the official API"
IDP_JSON="$(
  jq -nc \
    --arg clientSecret "${DEX_MEMOS_SECRET}" \
    '{
      title: "Dex",
      identifier_filter: "^zhyi$",
      type: "OAUTH2",
      config: {
        oauth2_config: {
          client_id: "memos",
          client_secret: $clientSecret,
          auth_url: "https://login.zhyi.xin/auth",
          token_url: "https://login.zhyi.xin/token",
          user_info_url: "https://login.zhyi.xin/userinfo",
          scopes: ["openid", "profile", "email", "groups"],
          field_mapping: {
            identifier: "preferred_username",
            display_name: "name",
            email: "email"
          }
        }
      }
    }'
)"
if rest_get "/api/v1/identity-providers" | jq -e '.identityProviders[] | select(.name == "identity-providers/dex-memos")' >/dev/null; then
  connect_call IdentityProviderService/UpdateIdentityProvider \
    "$(jq -nc --argjson idp "${IDP_JSON}" '{identity_provider:$idp, update_mask:{paths:["title","identifier_filter","config"]}}')" >/dev/null
else
  connect_call IdentityProviderService/CreateIdentityProvider \
    "$(jq -nc --arg id "dex-memos" --argjson idp "${IDP_JSON}" '{identity_provider_id:$id, identity_provider:$idp}')" >/dev/null
fi

echo "Configuring AI provider through Metapi through the official API"
AI_JSON="$(
  jq -nc \
    --arg apiKey "${METAPI_API_KEY}" \
    '{
      name: "instance/settings/AI",
      ai_setting: {
        providers: [
          {
            id: "metapi",
            title: "Metapi",
            type: "OPENAI",
            endpoint: "https://metapi.colocrossing.zhyi.cc/v1",
            api_key: $apiKey
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
      notification_setting: {
        email: {
          enabled: true,
          smtp_host: "send.ahasend.com",
          smtp_port: 587,
          smtp_username: "EjG9ROGAei",
          smtp_password: $smtpPassword,
          from_email: "postmaster@zhyi.cc",
          from_name: "Memos",
          reply_to: "",
          use_tls: true,
          use_ssl: false
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
      storage_setting: {
        storage_type: "LOCAL",
        filepath_template: "assets/{timestamp}_{filename}",
        upload_size_limit_mb: 64
      }
    }'
)"
connect_call InstanceService/UpdateInstanceSetting \
  "$(jq -nc --argjson setting "${STORAGE_JSON}" '{setting:$setting}')" >/dev/null

echo "Verifying applied settings"
rest_get "/api/v1/identity-providers/dex-memos" |
  jq '{name, title, identifier_filter, client_id: .config.oauth2_config.client_id, endpoints: [.config.oauth2_config.auth_url, .config.oauth2_config.token_url, .config.oauth2_config.user_info_url]}'
rest_get "/api/v1/instance/settings/AI" |
  jq '{name, providers: [.ai_setting.providers[] | {id, title, type, endpoint, api_key_set}]}'
rest_get "/api/v1/instance/settings/NOTIFICATION" |
  jq '{name, email_enabled: .notification_setting.email.enabled, smtp_host: .notification_setting.email.smtp_host, from_email: .notification_setting.email.from_email}'
rest_get "/api/v1/instance/settings/STORAGE" |
  jq '{name, storage_type: .storage_setting.storage_type, filepath_template: .storage_setting.filepath_template, upload_size_limit_mb: .storage_setting.upload_size_limit_mb}'
