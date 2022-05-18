# fetch-azure-function-local-settings

Gets the configuration settings of an azure function application, maps them with the local.settings.json format and resolves the keyvault values.

For now, it only works with Application Settings, so it won´t parse Connection Strings.

# What can I do with this?

Instead of getting the configurations of an azure function app or slot using the az tools, mapping them one by one into a local.settings.json file (as it has a different format), this script does that for you.

If you are using Keyvault for storing secrets or keys, it will also save you time as it can detect keyvault values in your configurations and automatically fetch the values. Remember that a local application cannot resolve keyvault values from its reference. So you would have to do it one by one.

# How can I use this

Please execute the Get-Help command in a Powershell console to see the how to use the script.
```powershell
Get-Help ./fetch-azure-function-local-settings.ps1
```

# How does it work?

It just executes az CLI commands.

# Pre requisites

## Azure CLI

Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli), as the script needs it.

## Login to your Azure account

If you are not logged in, the script will not be able to fetch the information and fail due to authorization errors. So after installing the CLI, login using:
```powershell
az login
```
Then, set your subscription. The subscription must be the one the application and keyvault (if necessary) are using. After login, you will see the subscriptions that are available for your account, and if you have more than one, check in the Azure Portal which one corresponds to your application/keyvault (in the overview page).
```powershell
az account set -s a-subscription-id
```

## Why Powershell?

I prefer a bash script, but I needed this for work and Powershell was the standard. It would be cool to have different versions of this script.
