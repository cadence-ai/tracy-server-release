# Génération du token
$rng   = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 32
$rng.GetBytes($bytes)
$token = [System.Convert]::ToBase64String($bytes)

$configPath = "config\config.json"

# Charger le JSON existant (s'il existe), sinon créer un objet vide
if (Test-Path $configPath) {
    $json   = Get-Content $configPath -Raw | ConvertFrom-Json
} else {
    $json   = [pscustomobject]@{}
}

# Mettre à jour uniquement la propriété token
if ($json.PSObject.Properties.Name -notcontains 'token') {
    # ajoute la propriété si elle n'existe pas
    $json | Add-Member -NotePropertyName 'token' -NotePropertyValue $token
} else {
    # met simplement à jour la valeur
    $json.token = $token
}

# Réécriture complète du JSON en conservant admin_token et le reste
$json | ConvertTo-Json -Depth 10 | Set-Content $configPath

Write-Host "Token généré : $token"

docker compose down
docker compose build --no-cache tracy
docker compose up -d
docker logs tracy --follow