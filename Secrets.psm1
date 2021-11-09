$ErrorActionPreference = "Stop"
### Change this value:
$SecretVault = "<A directory to store the key and encrypted password>"

Function New-Secret {
    param(
        [parameter(mandatory)]$Name,
        $Secret,
        $Description
    )
    $SecretFile = Join-Path $SecretVault "$Name.txt"
    $KeyFile = Join-Path $SecretVault "$Name.key"

    if(Test-Path $SecretFile) {
        $date = get-date -Format yyyyMMddHHmmss
        Rename-Item $SecretFile -NewName "$SecretFile-$date" -Force
        Rename-Item $KeyFile -NewName "$KeyFile-$date" -Force
    }

    $AESKey = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey)
    

    if (!$Secret) {
        $SecureSecret = Read-Host -Prompt "Enter Password" -AsSecureString 
    }
    else {
        $SecureSecret = ConvertTo-SecureString -String $Secret -Force -AsPlainText
    }

    if (!$Description) {
        $Description = Read-Host -Prompt "Enter Description"
    }
    Write-Verbose $SecureSecret 
    # Write-Verbose $AESKey
    $SecureSecretText = $SecureSecret | ConvertFrom-SecureString -Key $AESKey 

    $Secret = @{
        "Name"        = $Name
        "Encrypted"   = $SecureSecretText.ToString()
        "Description" = $Description
        "CreatedBy"   = $env:username
        "CreatedHost" = $env:computername
        "CreatedDate" = (Get-Date -format 'yyyy/MM/dd HH:mm:ss')
    }
    $SecretJson = ConvertTo-Json $Secret
    Write-Verbose $SecretJson
    Out-File -InputObject $SecretJson -FilePath $SecretFile -Encoding utf8 -Force -NoNewline
    Out-File -InputObject $AESKey -FilePath $KeyFile -Encoding utf8 -Force
    Write-Host "Secret $Name is created"
}

Function Get-SecretFilePath {
    param(
        $Name
    )
    $SecretFilePath = (Join-Path $SecretVault "$Name.txt")
    if(Test-Path $SecretFilePath) {
        Return $SecretFilePath
    } else {
        Write-Error "Secret not found"
    }
}

Function Get-SecretKeyPath {
    param(
        $Name
    )
    $SecretFilePath = (Join-Path $SecretVault "$Name.key")
    if(Test-Path $SecretFilePath) {
        Return $SecretFilePath
    } else {
        Write-Error "Secret Key not found"
    }
}

Function Get-Secret {
    param(
        $Name
    )

    $SecretFile = Get-SecretFilePath -Name $Name
    $KeyFile = Get-SecretKeyPath -Name $Name

    $Secret = Get-Content $SecretFile | ConvertFrom-Json
    $Key = Get-Content $KeyFile

    $SecureSecret = $Secret.Encrypted | ConvertTo-SecureString -Key $Key

    Return $SecureSecret
}

Function Get-SecretAsPlainText {
    param(
        $Name,
        $MagicWord
    )
    $SecretFile = Get-SecretFilePath -Name $Name
    $KeyFile = Get-SecretKeyPath -Name $Name

    $Secret = Get-Content $SecretFile | ConvertFrom-Json
    $Key = Get-Content $KeyFile

    $SuperUsers = Get-Content (Join-Path $SecretVault ".super.txt")

    $SecureSecret = $Secret.Encrypted | ConvertTo-SecureString -Key $Key
    if($($env:USERNAME).toLower() -in $SuperUsers){
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)
        $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        Return $PlainPassword
    } else {
        Write-Host "You are not a boss, returning a secure string instead"
        Return $SecureSecret
    }
}

Function Get-SecretsListing {
    param(
        $Name
    )

    $i = 1
    $Files = (Get-ChildItem -Path $SecretVault -Filter "*$Name*.txt" -Force).FullName
    if($Files){
        Write-Host "Secrets:"
        Write-Host "id, Name, Description, Createdby, CreatedDate"
        Write-Host "================================================"
    }
    Foreach($File in $Files) {
        $Secret = Get-Content $File | ConvertFrom-Json
        Write-Host "$i, $($Secret.Name), $($Secret.Description), $($Secret.CreatedBy), $($Secret.CreatedDate)"
        $i++
    }
}

Function Remove-Secret {
    Param (
        $Name
    )
    $SecretFile = Get-SecretFilePath -Name $Name
    $KeyFile = Get-SecretKeyPath -Name $Name

    Remove-Item $SecretFile -Force
    Remove-Item $KeyFile -Force
}
