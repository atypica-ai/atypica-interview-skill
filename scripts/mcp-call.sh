#!/usr/bin/env bash
#
# mcp-call.sh - Direct MCP tool call for Interview API
#
# Usage:
#   mcp-call.sh <tool_name> <json_args> [options]
#
# Examples:
#   mcp-call.sh atypica_interview_create_project '{"brief":"Research coffee","questions":[{"text":"What brand?"}]}'
#   mcp-call.sh atypica_interview_get_progress '{"projectId":123}'
#
# Environment:
#   ATYPICA_TOKEN    - API token from https://atypica.ai/account/api-keys
#   ATYPICA_ENDPOINT - API endpoint (default: https://atypica.ai/mcp/interview)
#
# Options:
#   -t, --token      API token (overrides ATYPICA_TOKEN)
#   -o, --output     Output format: text|json|structured|auto (default: auto)
#   -f, --file       Write output to file instead of stdout
#   -v, --verbose    Enable verbose output
#   -h, --help       Show this help message
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENDPOINT=${ATYPICA_ENDPOINT:-https://atypica.ai/mcp/interview}
OUTPUT_FORMAT="auto"
OUTPUT_FILE=""
VERBOSE=false

# Usage
usage() {
  cat << EOF
Usage: mcp-call.sh <tool_name> <json_args> [options]

Call MCP tools directly via HTTP API.

Arguments:
  tool_name    MCP tool name (e.g., atypica_interview_create_project)
  json_args    JSON-encoded arguments (e.g., '{"projectId":123}')

Options:
  -t, --token <token>      API token (overrides ATYPICA_TOKEN)
  -o, --output <format>    Output format: text|json|structured|auto (default: auto)
  -f, --file <path>        Write output to file instead of stdout
  -v, --verbose            Enable verbose output
  -h, --help               Show this help message

Environment Variables:
  ATYPICA_TOKEN     API token from https://atypica.ai/account/api-keys
  ATYPICA_ENDPOINT  API endpoint (default: https://atypica.ai/mcp/interview)

Examples:
  # Set token
  export ATYPICA_TOKEN="atypica_xxx"

  # Create interview project
  mcp-call.sh atypica_interview_create_project '{"brief":"Research coffee","questions":[{"text":"What brand?"}]}'

  # Get progress
  mcp-call.sh atypica_interview_get_progress '{"projectId":123}'

  # List completed sessions
  mcp-call.sh atypica_interview_list_sessions '{"projectId":123,"filter":"completed"}'

Available Tools:
  atypica_interview_create_project    - Create interview project
  atypica_interview_update_questions  - Update question list
  atypica_interview_list_projects     - List user's projects
  atypica_interview_generate_share_link - Generate share link
  atypica_interview_get_progress      - Get participation progress
  atypica_interview_list_sessions     - List sessions (paginated)
  atypica_interview_get_session       - Get session details
  atypica_interview_get_stats         - Get aggregated stats
  atypica_interview_generate_stats    - Trigger stats generation
  atypica_get_upload_credentials      - Get presigned upload URL

EOF
  exit 1
}

# Error handling
error() {
  echo -e "${RED}Error: $1${NC}" >&2
  exit 1
}

success() {
  echo -e "${GREEN}$1${NC}"
}

warn() {
  echo -e "${YELLOW}Warning: $1${NC}" >&2
}

info() {
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}Info: $1${NC}" >&2
  fi
}

# Check dependencies
check_dependencies() {
  if ! command -v curl &> /dev/null; then
    error "curl is required but not installed. Please install curl first."
  fi

  if ! command -v jq &> /dev/null; then
    warn "jq is not installed. Output formatting will be limited."
    warn "Install jq for better output: brew install jq (macOS) or apt-get install jq (Linux)"
  fi
}

# Parse arguments
parse_args() {
  local positional=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        usage
        ;;
      -t|--token)
        TOKEN="$2"
        shift 2
        ;;
      -o|--output)
        OUTPUT_FORMAT="$2"
        shift 2
        ;;
      -f|--file)
        OUTPUT_FILE="$2"
        shift 2
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done

  set -- "${positional[@]}"

  if [ ${#positional[@]} -lt 2 ]; then
    usage
  fi

  TOOL_NAME="${positional[0]}"
  ARGS="${positional[1]}"
  TOKEN="${TOKEN:-${ATYPICA_TOKEN:-}}"
}

# Main function
main() {
  parse_args "$@"

  # Validate token
  if [ -z "$TOKEN" ]; then
    error "API token is required. Set ATYPICA_TOKEN environment variable or use -t option."
  fi

  # Validate JSON
  if command -v jq &> /dev/null; then
    if ! echo "$ARGS" | jq empty 2>/dev/null; then
      error "Invalid JSON in arguments: $ARGS"
    fi
  fi

  info "Calling tool: $TOOL_NAME"
  info "Endpoint: $ENDPOINT"

  # Build request payload
  local payload
  payload=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "$TOOL_NAME",
    "arguments": $ARGS
  },
  "id": 1
}
EOF
)

  info "Request payload: $payload"

  # Make API call
  local response
  response=$(curl -s -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$payload")

  # Check for empty response
  if [ -z "$response" ]; then
    error "Empty response from API"
  fi

  info "Response received"
  info "Raw response (first 500 chars): ${response:0:500}"

  # Check if response is SSE format (starts with "event:" or "data:")
  if echo "$response" | head -1 | grep -q "^event:\|^data:"; then
    info "Detected SSE format, extracting JSON data"
    response=$(echo "$response" | grep "^data:" | sed 's/^data: //' | head -1)
    info "Extracted JSON (first 500 chars): ${response:0:500}"
  fi

  # Determine output destination
  local output_dest
  if [ -n "$OUTPUT_FILE" ]; then
    output_dest="$OUTPUT_FILE"
    info "Writing output to: $output_dest"
  else
    output_dest="/dev/stdout"
  fi

  # Check if response is valid JSON
  if command -v jq &> /dev/null; then
    if ! echo "$response" | jq empty 2>/dev/null; then
      error "Invalid JSON response from API. Raw response:\n$response"
    fi
  fi

  # Parse and display response
  if command -v jq &> /dev/null; then
    # Check for JSON-RPC error
    local error_code
    error_code=$(echo "$response" | jq -r '.error.code // empty')

    if [ -n "$error_code" ]; then
      local error_msg
      error_msg=$(echo "$response" | jq -r '.error.message')
      error "API Error [$error_code]: $error_msg"
    fi

    # Extract result based on output format and write to destination
    case "$OUTPUT_FORMAT" in
      text)
        echo "$response" | jq -r '.result.content[0].text // empty' > "$output_dest"
        ;;
      json)
        echo "$response" | jq '.' > "$output_dest"
        ;;
      structured)
        echo "$response" | jq -r '.result.structuredContent // empty' | jq '.' > "$output_dest"
        ;;
      auto|*)
        local text_content
        text_content=$(echo "$response" | jq -r '.result.content[0].text // empty')

        local structured_content
        structured_content=$(echo "$response" | jq -r '.result.structuredContent // empty')

        {
          if [ -n "$text_content" ] && [ "$text_content" != "null" ] && [ "$text_content" != "empty" ]; then
            echo "$text_content"
          fi

          if [ -n "$structured_content" ] && [ "$structured_content" != "null" ] && [ "$structured_content" != "empty" ]; then
            echo "$structured_content" | jq '.'
          fi

          if [ -z "$text_content" ] || [ "$text_content" = "null" ] || [ "$text_content" = "empty" ]; then
            if [ -z "$structured_content" ] || [ "$structured_content" = "null" ] || [ "$structured_content" = "empty" ]; then
              echo "$response" | jq '.'
            fi
          fi
        } > "$output_dest"
        ;;
    esac

    if [ -n "$OUTPUT_FILE" ]; then
      success "Output written to: $OUTPUT_FILE"
    fi
  else
    echo "$response" > "$output_dest"

    if [ -n "$OUTPUT_FILE" ]; then
      success "Output written to: $OUTPUT_FILE"
    fi
  fi
}

# Check dependencies first
check_dependencies

# Run main function
main "$@"
