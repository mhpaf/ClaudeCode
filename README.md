# Azure AI Foundry & Claude Code Environment

Dieses Projekt automatisiert die Bereitstellung einer sicheren Entwicklungsumgebung in Microsoft Azure. Es erstellt eine virtuelle Maschine (Ubuntu), auf der **Claude Code** (das CLI-Tool von Anthropic) bereits vorinstalliert ist, und konfiguriert die notwendige **Azure AI Foundry** Infrastruktur, damit Claude Code über Azure (statt direkt über Anthropic) läuft.

## 📋 Inhaltsverzeichnis

1. [Architektur & Konzept](#architektur--konzept)
2. [Voraussetzungen](#voraussetzungen)
3. [Installation & Deployment](#installation--deployment)
4. [WICHTIG: Manueller Schritt (Modell Deployment)](#wichtig-manueller-schritt-modell-deployment)
5. [Verwendung](#verwendung)
6. [Troubleshooting](#troubleshooting)

---

## 🏗 Architektur & Konzept

Das Terraform-Skript baut folgende Komponenten auf. Hier erklären wir, **was** gebaut wird, **warum** es benötigt wird und **wie** es konfiguriert ist.

### 1. Compute & Netzwerk (Die VM)
*   **Resource:** `azurerm_linux_virtual_machine` (Ubuntu 24.04 LTS)
*   **Größe:** `Standard_B2ms` (2 vCPUs, 8 GB RAM).
    *   *Warum:* Diese Größe ist kosteneffizient ("Burstable"), bietet aber genug RAM für Node.js/CLI-Prozesse und Kompilierungen.
*   **Netzwerk:** Eigenes VNet (`10.2.0.0/16`) mit Public IP.
    *   *Warum:* Isoliert die Entwicklungsumgebung vom Rest deiner Infrastruktur. SSH ist erlaubt.

### 2. Identity (Sicherheit)
*   **Resource:** `azurerm_user_assigned_identity`
*   **Konzept:** Managed Identity ("Keyless Auth").
    *   *Warum:* Wir speichern **keine** API-Keys auf der VM. Die VM erhält eine Azure-Identität. Wir weisen dieser Identität Rechte zu (`Azure AI Developer`), damit sie mit dem AI Foundry Projekt sprechen darf.
    *   *Vorteil:* Wenn du `az login --identity` auf der VM ausführst (passiert automatisch via Script), bist du sofort authentifiziert.

### 3. AI Infrastructure (Das "Hirn")
Hier nutzen wir den `azapi` Provider, da diese Ressourcen sehr neu sind.
*   **Azure AI Hub:** Der Container für AI-Ressourcen, verknüpft mit Cognitive Services.
*   **Azure AI Project:** Der Arbeitsbereich, in dem Deployments (wie Claude 3.5 Sonnet) leben.
    *   *Zweck:* Claude Code auf der VM verbindet sich mit diesem Project, um Prompts zu senden.

### 4. Automation (Cloud-Init)
*   **Was passiert beim Booten?**
    1.  Installation von **Azure CLI** (für die Authentifizierung).
    2.  Installation von **Claude Code** (via offiziellem Installer).
    3.  Setzen von globalen **Umgebungsvariablen** (`/etc/environment`), damit Claude Code weiß: "Ich soll Azure Foundry nutzen, nicht Anthropic direkt".
    4.  Einrichten eines Auto-Login Scripts (`/etc/profile.d/`), damit du beim SSH-Login sofort mit Azure verbunden bist.

---

## ✅ Voraussetzungen

Bevor du startest, stelle sicher, dass du Folgendes hast:

1.  **Terraform installiert** (v1.5+).
2.  **Azure CLI installiert** und lokal eingeloggt (`az login`).
3.  **Eine existierende Resource Group** in Azure (auf die du Zugriff hast).
4.  **Subscription ID** deiner Azure Subscription.

---

## 🚀 Installation & Deployment

### 1. Projektstruktur anlegen
Erstelle einen Ordner und speichere den Terraform-Code in eine Datei namens `main.tf`.

### 2. Terraform initialisieren
Lade die notwendigen Provider herunter:

```bash
terraform init
