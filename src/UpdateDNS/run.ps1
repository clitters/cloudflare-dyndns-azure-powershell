using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Test if API Token is provided in environment
if (-not $env:API_TOKEN) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::Unauthorized
        #Body = "API Token is not provided in the environment variables."
    })
    return
}
# Test if Email is provided in environment
if (-not $env:API_EMAIL) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::Unauthorized
        #Body = "Email is not provided in the environment variables."
    })
    return
}
# Test for ProxyPreference
if (-not $env:ProxyPreference) {
    $env:ProxyPreference = $false
}
else {
    $env:ProxyPreference = $true
}

# Interact with query parameters or the body of the request.
$DnsName = $Request.Query.DnsName
if (-not $DnsName) {
    $DnsName = $Request.Body.DnsName
}
$Ip = $Request.Query.Ip
if (-not $Ip) {
    $Ip = $Request.Body.Ip
}

# Validate the input parameters
if (-not $DnsName -or -not $Ip) {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = "Please provide both DnsName and Ip in the query string or in the request body."
    })
    return
}
if (-not $DnsName -match '^[a-zA-Z0-9.-]+$') {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = "Invalid DnsName format. Only alphanumeric characters, dots, and hyphens are allowed."
    })
    return
}

$uri = "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_RECORD_ID";

$params = @{
  Uri         = $uri
  Method      = PATCH
  ContentType = 'application/json'
  Headers     = @{'X-Auth-Email' = "$env:API_EMAIL"; 'X-Auth-Key' = "$Env:API_TOKEN"}
  Body        = ConvertTo-Json -Compress -InputObject @{
    Name = $DnsName
    ttl = 60
    type = "A"
    content = $Ip
    proxied = $env:ProxyPreference 
  }
}

try {
    Invoke-RestMethod @params -ErrorAction Stop
    $body = "DNS record for $DnsName updated successfully to IP $Ip."
}
catch {
    else {
        $errorMessage = $_.Exception.Message
        Write-Host "Error updating DNS record: $errorMessage"
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::InternalServerError
            Body = "Failed to update DNS record: $errorMessage"
        })
        return
    }
}


# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
