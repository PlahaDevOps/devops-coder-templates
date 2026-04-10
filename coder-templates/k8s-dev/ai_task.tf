# Registers this template for Coder Tasks (global /tasks UI lists templates that expose coder_ai_task).
# See: https://registry.terraform.io/providers/coder/coder/latest/docs/resources/ai_task
resource "coder_ai_task" "claude" {
  count = data.coder_workspace.me.start_count

  app_id = module.claude_code[count.index].task_app_id
}
