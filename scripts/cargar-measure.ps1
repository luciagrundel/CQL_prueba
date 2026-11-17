param(
    [string]$BaseUrl = 'http://localhost:8080/fhir',
    [int]$EsperaSegundos = 240
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$BaseUrl = $BaseUrl.TrimEnd('/')
$source = [IO.File]::ReadAllText("$root/cql/CoberturaPesoAdultos.cql")
$library = @{
    resourceType = 'Library'; id = 'cobertura-peso-adultos'
    url = 'http://example.org/fhir/Library/CoberturaPesoAdultos'
    name = 'CoberturaPesoAdultos'; version = '1.0.2'; status = 'draft'; experimental = $true
    type = @{ coding = @(@{ system = 'http://terminology.hl7.org/CodeSystem/library-type'; code = 'logic-library' }) }
    content = @(@{ contentType = 'text/cql'; data = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($source)) })
}
# Genera el recurso revisable antes de cargarlo. No ejecuta el indicador.
$libraryJson = $library | ConvertTo-Json -Depth 50
$libraryJson | Set-Content "$root/data/library-cobertura-peso-adultos.json" -Encoding UTF8
$measure = Get-Content "$root/data/measure-cobertura-peso-adultos.json" -Raw | ConvertFrom-Json
Write-Host "Esperando disponibilidad de HAPI en $BaseUrl..."
$deadline = (Get-Date).AddSeconds($EsperaSegundos)
do {
    try {
        $metadata = Invoke-RestMethod -Uri "$BaseUrl/metadata" `
            -Headers @{ Accept = 'application/fhir+json' } -TimeoutSec 10
        if ($metadata.resourceType -eq 'CapabilityStatement') { break }
    } catch { }
    if ((Get-Date) -ge $deadline) {
        throw "HAPI no esta listo en $BaseUrl. Revisa: docker compose logs --tail 100 hapi"
    }
    Start-Sleep -Seconds 3
} while ($true)
foreach ($resource in @($library, $measure)) {
    $json = $resource | ConvertTo-Json -Depth 50
    $null = Invoke-RestMethod -Method Put -Uri "$BaseUrl/$($resource.resourceType)/$($resource.id)" `
        -Headers @{ Accept = 'application/fhir+json' } -ContentType 'application/fhir+json; charset=utf-8' `
        -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 120
    Write-Host "Cargado $($resource.resourceType)/$($resource.id)"
}
