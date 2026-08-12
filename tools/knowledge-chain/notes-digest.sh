#!/usr/bin/env bash
# Notes -> UniAPI -> Memos digest loop using official APIs only.
# Reads private Notes from Gitea, summarizes them through UniAPI, and writes
# the result back into Memos. It never touches any database directly.
set -euo pipefail

GITEA_BASE_URL="${GITEA_BASE_URL:-https://git.zhyi.xin}"
GITEA_REPO="${GITEA_REPO:-zhyi/notes}"
UNIAPI_BASE_URL="${UNIAPI_BASE_URL:-https://uni-api.rock5c.zhyi.cc}"
MEMOS_BASE_URL="${MEMOS_BASE_URL:-http://127.0.0.1:13819}"
AI_MODEL="${AI_MODEL:-deepseek-v4-flash:opencode-go}"
MEMOS_VISIBILITY="${MEMOS_VISIBILITY:-PRIVATE}"
MAX_INPUT_BYTES="${MAX_INPUT_BYTES:-120000}"
NOTES_PREFIX="${NOTES_PREFIX:-}"
DRY_RUN="${DRY_RUN:-}"
OUTPUT_FILE="${OUTPUT_FILE:-}"

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

GITEA_TOKEN="$(read_secret GITEA_TOKEN "${GITEA_TOKEN_FILE:-/run/secrets/gitea-ai-token}")"
UNIAPI_KEY="$(read_secret UNIAPI_KEY "${UNIAPI_KEY_FILE:-/run/secrets/uni-api-admin-api-key}")"
MEMOS_TOKEN="$(read_secret MEMOS_TOKEN "${MEMOS_TOKEN_FILE:-/run/secrets/memos-ai-token}")"

GITEA_AUTH=(-H "Authorization: token ${GITEA_TOKEN}")
UNIAPI_AUTH=(-H "Authorization: Bearer ${UNIAPI_KEY}")
MEMOS_AUTH=(-H "Authorization: Bearer ${MEMOS_TOKEN}")
JSON=(-H "Content-Type: application/json")

echo "Fetching Gitea repository metadata through the official API"
repo_json="$(
  curl -fsS --retry 3 "${GITEA_AUTH[@]}" \
    "${GITEA_BASE_URL}/api/v1/repos/${GITEA_REPO}"
)"
default_branch="$(jq -r '.default_branch // "master"' <<<"${repo_json}")"

echo "Resolving ${default_branch} commit through the official API"
branch_json="$(
  curl -fsS --retry 3 "${GITEA_AUTH[@]}" \
    "${GITEA_BASE_URL}/api/v1/repos/${GITEA_REPO}/branches/${default_branch}"
)"
tree_sha="$(jq -r '.commit.id // empty' <<<"${branch_json}")"
if [[ -z "${tree_sha}" ]]; then
  echo "failed to resolve branch ${default_branch}" >&2
  exit 1
fi

echo "Listing Markdown files in ${GITEA_REPO}@${default_branch}"
tree_json="$(
  curl -fsS --retry 3 "${GITEA_AUTH[@]}" \
    "${GITEA_BASE_URL}/api/v1/repos/${GITEA_REPO}/git/trees/${tree_sha}?recursive=true"
)"
paths="$(
  jq -r '.tree[]? | select(.type == "blob") | .path' <<<"${tree_json}" \
    | rg '\.md$' || true
)"
if [[ -n "${NOTES_PREFIX}" ]]; then
  paths="$(
    printf '%s\n' "${paths}" \
      | rg "^${NOTES_PREFIX}/" || true
  )"
fi
if [[ -z "${paths}" ]]; then
  echo "no Markdown files found in ${GITEA_REPO}" >&2
  exit 1
fi

combined=""
nl=$'\n'
byte_count=0
while IFS= read -r path; do
  [[ -n "${path}" ]] || continue
  encoded_path="$(jq -rn --arg p "${path}" '$p | @uri')"
  content_json="$(
    curl -fsS --retry 3 "${GITEA_AUTH[@]}" \
      "${GITEA_BASE_URL}/api/v1/repos/${GITEA_REPO}/contents/${encoded_path}?ref=${default_branch}"
  )"
  content_b64="$(jq -r '.content // empty' <<<"${content_json}")"
  [[ -n "${content_b64}" ]] || continue
  decoded="$(printf '%s' "${content_b64}" | base64 -d 2>/dev/null || true)"
  [[ -n "${decoded}" ]] || continue
  combined+="# ${path}${nl}${decoded}${nl}${nl}"
  byte_count="$(printf '%s' "${combined}" | wc -c | tr -d ' ')"
  if (( byte_count > MAX_INPUT_BYTES )); then
    combined="$(printf '%s' "${combined}" | head -c "${MAX_INPUT_BYTES}")"
    echo "input truncated at ${MAX_INPUT_BYTES} bytes" >&2
    break
  fi
done <<<"${paths}"

if [[ -z "${combined}" ]]; then
  echo "failed to read any Markdown content from Gitea" >&2
  exit 1
fi

echo "Summarizing with ${AI_MODEL} through UniAPI"
completion_payload="$(
  jq -nc \
    --arg model "${AI_MODEL}" \
    --arg content "${combined}" \
    '{
      model: $model,
      messages: [
        {
          role: "system",
          content: "你是私有知识整理助手。请基于提供的 Markdown 笔记生成简洁中文摘要，保留关键结论、链接和待办。不要编造笔记中不存在的信息。"
        },
        { role: "user", content: $content }
      ],
      temperature: 0.2
    }'
)"
completion_json="$(
  curl -fsS --retry 3 "${UNIAPI_AUTH[@]}" "${JSON[@]}" \
    -X POST --data "${completion_payload}" \
    "${UNIAPI_BASE_URL}/v1/chat/completions"
)"
summary="$(jq -r '.choices[0].message.content // empty' <<<"${completion_json}")"
if [[ -z "${summary}" ]]; then
  echo "UniAPI returned an empty summary" >&2
  exit 1
fi

if [[ -n "${OUTPUT_FILE}" ]]; then
  printf '%s\n' "${summary}" > "${OUTPUT_FILE}"
  echo "summary written to ${OUTPUT_FILE}"
fi

if [[ -n "${DRY_RUN}" ]]; then
  echo "[dry-run] would write summary to Memos:"
  printf '%s\n' "${summary}"
  exit 0
fi

echo "Writing summary back to Memos through the official API"
memo_payload="$(
  jq -nc \
    --arg content "${summary}" \
    --arg visibility "${MEMOS_VISIBILITY}" \
    '{ content: $content, visibility: $visibility }'
)"
memo_json="$(
  curl -fsS --retry 3 "${MEMOS_AUTH[@]}" "${JSON[@]}" \
    -X POST --data "${memo_payload}" \
    "${MEMOS_BASE_URL}/api/v1/memos"
)"
jq -r '.name // .id // empty' <<<"${memo_json}"
