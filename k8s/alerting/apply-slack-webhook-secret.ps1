param(
    [string]$EnvFilePath = ".env",
    [string]$Namespace = "monitoring",
    [string]$SecretName = "alertmanager-slack-webhook"
)

if (-not (Test-Path -Path $EnvFilePath)) {
    Write-Error "Env file not found: $EnvFilePath"
    exit 1
}

# Lightweight .env parser for KEY=VALUE lines.
$envMap = @{}
Get-Content -Path $EnvFilePath | ForEach-Object {
    $line = $_.Trim()

    if ($line -eq "" -or $line.StartsWith("#")) {
        return
    }

    $idx = $line.IndexOf("=")
    if ($idx -le 0) {
        return
    }

    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()

    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
    }

    $envMap[$key] = $value
}

$webhookUrl = $envMap["SLACK_WEBHOOK_URL"]
if ([string]::IsNullOrWhiteSpace($webhookUrl)) {
    Write-Error "SLACK_WEBHOOK_URL is missing in $EnvFilePath"
    exit 1
}

kubectl create secret generic $SecretName --namespace $Namespace --from-literal="url=$webhookUrl" --dry-run=client -o yaml | kubectl apply -f -
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create/apply secret $SecretName in namespace $Namespace"
    exit $LASTEXITCODE
}

Write-Host "Secret $SecretName applied in namespace $Namespace using value from $EnvFilePath"
