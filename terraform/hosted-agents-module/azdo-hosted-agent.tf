resource "azurerm_virtual_machine_extension" "installtools" {
    name                       = "customconfig"
    virtual_machine_id         = azurerm_linux_virtual_machine.devopsvm.id
    publisher                  = "Microsoft.Azure.Extensions"
    type                       =  "CustomScript"
    type_handler_version       = "2.0"
    protected_settings = <<SETTINGS
    {
      "script" : "${base64encode(templatefile("${path.module}/install_tools.sh", {
        AGENT_USER = var.agent_user
        AGENT_POOL = "${var.agent_pool_prefix}-${var.environment}"
        AGENT_TOKEN = var.agent_token
        AZDO_URL = var.azdo_url
      }))}"
    }
    SETTINGS
    depends_on = [azurerm_linux_virtual_machine.devopsvm]
}