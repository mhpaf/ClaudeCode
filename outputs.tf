output "ssh_command" {
  value = "ssh -i claude_key.pem azureuser@${azurerm_public_ip.pip.ip_address}"
}

output "foundry_project_name" {
  value = azapi_resource.ai_project.name
}

output "manual_step_required" {
  value = "WICHTIG: Gehe ins Azure AI Foundry Portal (https://ai.azure.com), wähle das Project '${azapi_resource.ai_project.name}' und deploye das Modell 'Claude 3.5 Sonnet' MANUELL. Nenne das Deployment exakt so, wie du es im Code nutzen willst (z.B. 'claude-3-5-sonnet')."
}
