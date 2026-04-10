# Replaces coder-login for CODER_URL: the stock module sets CODER_URL to data.coder_workspace.me.access_url
# (e.g. ngrok), which from inside the pod returns HTML interstitials → JSON parse errors for `coder` CLI.
# Session token matches coder-login; URL points at the API reachable from the pod (see local.coder_agent_api_url).
resource "coder_env" "coder_session_token" {
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.main.id
  name     = "CODER_SESSION_TOKEN"
  value    = data.coder_workspace_owner.me.session_token
}

resource "coder_env" "coder_url" {
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.main.id
  name     = "CODER_URL"
  value    = local.coder_agent_api_url
}
