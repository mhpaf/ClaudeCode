# --- Data Sources (Bestehende Ressourcen lesen) ---
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

data "cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!/bin/bash
      
      # 1. Basis Tools & Azure CLI installieren
      curl -sL https://aka.ms/InstallAzureCLIDeb | bash
      apt-get update && apt-get install -y unzip jq

      # 2. Claude Code installieren (Global)
      curl -fsSL https://claude.ai/install.sh | bash
      
      # Verschieben für globalen Zugriff
      if [ -f /root/.local/bin/claude ]; then
        mv /root/.local/bin/claude /usr/local/bin/claude
        chmod +x /usr/local/bin/claude
      fi

      # 3. Umgebungsvariablen für ALLE User setzen (/etc/environment)
      # Diese Variablen sagen Claude Code: "Nutz Foundry statt Anthropic direkt"
      echo "CLAUDE_CODE_USE_FOUNDRY=1" >> /etc/environment
      echo "ANTHROPIC_FOUNDRY_RESOURCE=${azapi_resource.ai_project.name}" >> /etc/environment
      # Optional: Fallback Region, falls nötig
      # echo "ANTHROPIC_FOUNDRY_LOCATION=${var.location}" >> /etc/environment

      # 4. Auto-Login via Managed Identity für den User 'azureuser'
      # Wir legen ein Script in profile.d, das beim Login läuft
      cat <<EOT > /etc/profile.d/00-azure-login.sh
      # Prüfen ob schon eingeloggt
      az account show > /dev/null 2>&1
      if [ \$? -ne 0 ]; then
          echo "Logging in to Azure with Managed Identity..."
          az login --identity --allow-no-subscriptions > /dev/null 2>&1
      fi
      EOT
      
      chmod +x /etc/profile.d/00-azure-login.sh
    EOF
  }
}
