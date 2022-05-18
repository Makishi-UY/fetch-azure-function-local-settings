<#
    .SYNOPSIS
    Generates an object with the content of a local.settings.json formatted file from an already deployed Azure Function's configuration.

    .DESCRIPTION
    Creates an object that can be copied as the content of the local.settings.json file of an Azure Function project, in order to correctly build and run locally an Azure Function solution.

    .INPUTS
    None. You cannot pipe objects to this script.

    .OUTPUTS
    Copies the json contents to the clipboard.

    .EXAMPLE
    PS> ./sync-settings.ps1 -appName aname -resourceGroup rg -keyVaultName kvn

    .EXAMPLE
    PS> ./sync-settings.ps1 -appName aname -resourceGroup rg -keyVaultName kvn -slotName slotname
#>

# Parameter definition and validations.
param (
    [parameter(Mandatory = $true, HelpMessage = "The Azure Function name.")][String]
    # The Azure Function name.
    $appName,
    [parameter(Mandatory = $false, HelpMessage = "If a slot is the target, the name must be specified.")][String]
    # If a slot is the target, the name must be specified.
    $slotName,
    [parameter(Mandatory = $true, HelpMessage = "The Resource Group of the Function App.")][String]
    # The Resource Group of the Function App.
    $resourceGroup,
    [parameter(Mandatory = $false, HelpMessage = "The keyvault name to fetch the secrets (if any).")][String]
    # The keyvault name to fetch the secrets (if any).
    $keyVaultName
)

function Write-Info ([string] $message) {
    Write-Host $message -ForegroundColor DarkGreen
}

function Write-Message ([string] $message) {
    Write-Host "==> " -NoNewline -ForegroundColor Green
    Write-Host $message
}

function Write-Warning ([string] $message) {
    Write-Host $message -ForegroundColor Yellow
}

function Write-Separator () {
    Write-Host "---------------------------------------------------" -ForegroundColor DarkGray
}

function Write-NewLine ([int32] $lines) {
    for (($i = 0); $i -lt $lines; $i++) {
        Write-Host ""
    }
}

function Read-Confirmation ([string] $confirmationMessage, [string] $successMessage) {
    $confirmation = Read-Host $confirmationMessage
    if ($confirmation -eq 'y') {
        Set-Clipboard $jsonConfiguration
        Write-Message $successMessage
    }
}

#### Initial Validations.
Write-Info "Please make sure you have the Azure Functions Core Tools installed  (please refer to https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=v4%2Cwindows%2Ccsharp%2Cportal%2Cbash)"
Write-Info "and that you are logged in with your Azure account using the Azure CLI tools (please refer to https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli)"
Write-NewLine -lines 1
Write-Info "You should also set the active subscription after login in order to let the script operate correctly"
Write-Separator

# Check passed keyVaultName parameter.
If (!!$keyVaultName) {
    Write-Message "Validating provided keyvault name..."
    $keyVaultInfo = az keyvault show --name $keyVaultName | ConvertFrom-Json
    if (!$keyVaultInfo.id) {
        Write-Message $keyVaultInfo
        Exit
    }
    else {
        Write-Message "   Found Keyvault $($keyVaultInfo.id | ConvertTo-Json)"
        Write-NewLine -lines 1
    }
}

#### Data fetched from azure CLI tools returns an array of objects with this structure:
# {
#     name: string,
#     slotSetting: boolean,
#     value: string
# }
#
# So, converting from json will result in an array of objects with that structure.
Write-Message "Requesting settings from the Azure Platform..."
$azCommand = 'az'
$azParams = "functionapp", "config", "appsettings", "list", "--name", "$appName", "--resource-group", "$resourceGroup"
if (!!$slotName) {
    $azParams = $azParams + "--slot" + "$slotName"
}
$functionAppDefinition = & $azCommand $azParams | ConvertFrom-Json

#### Format the fetched settings and deduce the keyvault values (if any).
Write-Message "Formatting values..."
$localSettings = New-Object -TypeName PSObject
$countKeyvaultReferences = 0
foreach ($setting in $functionAppDefinition) {
    $value = If (($setting.value -match '.*/secrets/(.+)/.*' -and ++$Script:countKeyvaultReferences) -and !!$keyVaultName) {
        Write-Progress -Activity "Resolving keyvault value" -CurrentOperation $setting.name
        (az keyvault secret show --vault-name $keyVaultName --name $matches[1] | ConvertFrom-Json).value
    }
    Else {
        $setting.value
    }    
    $localSettings | Add-Member -MemberType NoteProperty -Name $setting.name -Value $value
}

# No connection strings formatting for now.
$connectionStrings = New-Object -TypeName PSObject

# Enable CORS for development purposes.
$corsSettings = New-Object -TypeName PSObject
$corsSettings | Add-Member -MemberType NoteProperty -Name "CORS" -Value "*"

#### Create and format the settings file and fill in with fetched configurations.
$configurationFile = New-Object -TypeName PSObject
$configurationFile | Add-Member -MemberType NoteProperty -Name "IsEncrypted" -Value $false
$configurationFile | Add-Member -MemberType NoteProperty -Name "Values" -Value $localSettings
$configurationFile | Add-Member -MemberType NoteProperty -Name "Host" -Value $corsSettings
$configurationFile | Add-Member -MemberType NoteProperty -Name "ConnectionStrings" -Value $connectionStrings

#### Return data.
$jsonConfiguration = $configurationFile | ConvertTo-Json

Write-NewLine -lines 3
Write-Message "The following local.settings.json file content was created:"
Write-Separator
$jsonConfiguration
Write-Separator

If (!$keyVaultName -and $countKeyvaultReferences -gt 0) {
    Write-Warning "$countKeyvaultReferences keyvault references where found, you can use the 'keyVaultName' param to automatically fetch their values (Use Powershell's Get-Help for more examples)."
}
Else {
    Write-Message "Resolved $countKeyvaultReferences keyvault references during the process"
}

Read-Confirmation -confirmationMessage "Do you want to copy the settings content into the clipboard? [y/n]" -successMessage "Content of fetched local.settings.json was copied into the clipboard!"
