#requires -version 5.1
<#
LINKON OFFICE TOOL v3.0
Fluxo recomendado:
1) Diagnóstico -> 2) Remover Office antigo -> 3) Instalar Office 2024 -> 4) Verificar.
A opção 1 executa o fluxo completo com confirmações.
A ativação aceita somente chave/licença legítima.
#>

$ErrorActionPreference = "Stop"

# ============================================================
# LINKON BRAND SYSTEM
# Paleta baseada na identidade visual da logo
# Fundo: #070012 | Magenta: #F80677 | Apoio: #4F0837
# ============================================================
$Brand = @{
    Name      = "LINKON"
    Product   = "OFFICE TOOL"
    Version   = "3.0"
    Primary   = "Magenta"
    Secondary = "DarkMagenta"
    Text      = "White"
    Muted     = "DarkGray"
    Success   = "Green"
    Warning   = "Yellow"
    Error     = "Red"
    Info      = "Cyan"
}

try {
    $host.UI.RawUI.WindowTitle = "LINKON • OFFICE TOOL v$($Brand.Version)"
    $host.UI.RawUI.BackgroundColor = "Black"
    $host.UI.RawUI.ForegroundColor = "White"
    Clear-Host
} catch {}

function Write-Line([string]$text = "", [string]$color = "White") {
    Write-Host $text -ForegroundColor $color
}

function Write-Center([string]$text, [string]$color = "White", [int]$width = 68) {
    $t = if($text.Length -gt $width){$text.Substring(0,$width)}else{$text}
    $pad = [Math]::Max(0,[int](($width - $t.Length) / 2))
    Write-Line ((" " * $pad) + $t) $color
}

function Write-BrandBanner {
    Clear-Host
    Write-Line ""
    Write-Line "  +------------------------------------------------------------------+" $Brand.Secondary
    Write-Line "  |                                                                  |" $Brand.Secondary
    Write-Center "LINKON" $Brand.Primary
    Write-Center "OFFICE TOOL  •  v$($Brand.Version)" $Brand.Text
    Write-Center "ATENDIMENTO • DIAGNOSTICO • INSTALACAO • REPARO" $Brand.Info
    Write-Line "  |                                                                  |" $Brand.Secondary
    Write-Line "  +------------------------------------------------------------------+" $Brand.Secondary
    Write-Line ""
}

function Write-Section([string]$title) {
    Write-Line ""
    Write-Line ("  +-- {0} " -f $title.ToUpper()) $Brand.Primary
    Write-Line "  +------------------------------------------------------------------+" $Brand.Secondary
}

function Write-OK([string]$message) { Write-Line "  [OK] $message" $Brand.Success }
function Write-Warn([string]$message) { Write-Line "  [!] $message" $Brand.Warning }
function Write-Fail([string]$message) { Write-Line "  [X] $message" $Brand.Error }
function Write-Info([string]$message) { Write-Line "  [i] $message" $Brand.Info }

function Write-MenuItem([string]$number,[string]$label,[bool]$highlight=$false) {
    $color = if($highlight){$Brand.Primary}else{$Brand.Text}
    Write-Line ("  [{0}]  {1}" -f $number,$label) $color
}

function Show-SystemSummary {
    Write-Section "AMBIENTE"
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $arch = if([Environment]::Is64BitOperatingSystem){"x64"}else{"x86"}
    $net = if(Test-Net){"ONLINE"}else{"OFFLINE"}
    Write-Line ("  PC          {0}" -f $env:COMPUTERNAME) $Brand.Text
    if($os){ Write-Line ("  WINDOWS     {0}" -f $os.Caption) $Brand.Text }
    Write-Line ("  ARQUITETURA {0}    REDE {1}" -f $arch,$net) $(if($net -eq 'ONLINE'){$Brand.Success}else{$Brand.Warning})
    if($cs){ Write-Line ("  MEMORIA     {0:N1} GB" -f ($cs.TotalPhysicalMemory/1GB)) $Brand.Text }
}
$Root = "C:\LinkOnOffice"
$LogDir = Join-Path $Root "Logs"
$ODTExe = Join-Path $Root "OfficeDeploymentTool.exe"
$SetupExe = Join-Path $Root "setup.exe"

New-Item -ItemType Directory -Force -Path $Root,$LogDir | Out-Null
$Log = Join-Path $LogDir ("LinkOnOffice_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
Start-Transcript -Path $Log -Append | Out-Null

function Pause-L { Write-Line ""; Read-Host "Pressione ENTER para continuar" | Out-Null }

function Is-Admin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Is-Admin)) {
    Write-Warn "Abrindo novamente como Administrador..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Stop-Transcript | Out-Null
    exit
}

function Test-Net {
    try {
        $r=Invoke-WebRequest "https://www.microsoft.com" -Method Head -UseBasicParsing -TimeoutSec 15
        return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500)
    } catch { return $false }
}

function Download-ODT {
    if (Test-Path $SetupExe) {
        Write-OK "ODT já disponível."
        return
    }
    if (-not (Test-Net)) { throw "Sem acesso à internet. Conecte o computador à internet e tente novamente." }

    # Página oficial do Download Center. O script localiza o EXE atual em vez de fixar uma versão antiga.
    $page = "https://www.microsoft.com/en-us/download/details.aspx?id=49117"
    Write-Host "[+] Consultando o Download Center oficial da Microsoft..." -ForegroundColor Cyan
    $html = (Invoke-WebRequest $page -UseBasicParsing).Content

    $matches = [regex]::Matches($html,'https?://[^"''\s<>]+/officedeploymenttool[^"''\s<>]*\.exe')
    if ($matches.Count -eq 0) {
        # Fallback: procura qualquer URL .exe contendo officedeploymenttool no HTML.
        $matches = [regex]::Matches($html,'https?://[^"''\s<>]*officedeploymenttool[^"''\s<>]*\.exe')
    }
    if ($matches.Count -eq 0) {
        throw "A Microsoft alterou a página de download e o instalador não pôde ser localizado automaticamente."
    }

    $url = ($matches | Select-Object -First 1).Value
    Write-Host "[+] Baixando ODT oficial..." -ForegroundColor Cyan
    Invoke-WebRequest $url -OutFile $ODTExe -UseBasicParsing

    Write-Host "[+] Extraindo ODT..." -ForegroundColor Cyan
    $p=Start-Process $ODTExe -ArgumentList "/quiet /extract:`"$Root`"" -Wait -PassThru
    if ($p.ExitCode -ne 0 -or -not (Test-Path $SetupExe)) {
        throw "A ODT não foi extraída corretamente. Código: $($p.ExitCode)"
    }
    Write-OK "ODT pronta."
}

function Get-OfficeProducts {
    $paths=@(
      "$env:ProgramFiles\Microsoft Office",
      "${env:ProgramFiles(x86)}\Microsoft Office",
      "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun",
      "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun"
    ) | Where-Object { $_ -and (Test-Path $_) }

    Write-Section "DETECÇÃO DO OFFICE"
    foreach($p in $paths){ Write-Host "[+] $p" }

    $uninstall=@(
      "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
      "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $items=foreach($u in $uninstall){ Get-ItemProperty $u -ErrorAction SilentlyContinue }
    $office=$items | Where-Object { $_.DisplayName -match 'Microsoft Office|Microsoft 365|Office LTSC|Visio|Project' }
    if($office){
      $office | Sort-Object DisplayName | ForEach-Object { Write-Host " - $($_.DisplayName) $($_.DisplayVersion)" }
    } else {
      Write-Host "Nenhum produto Office detectado no registro." -ForegroundColor DarkGray
    }
}

function Write-Xml($name,$content){
    $path=Join-Path $Root $name
    Set-Content $path $content -Encoding UTF8
    return $path
}

function Run-ODT($cfg){
    $p=Start-Process $SetupExe -ArgumentList "/configure `"$cfg`"" -Wait -PassThru
    if($p.ExitCode -ne 0){ throw "ODT retornou código $($p.ExitCode)." }
}

function Remove-Office {
    Download-ODT
    Write-Host "`n[!] A remoção apaga os produtos Office instalados. Salve documentos abertos antes de continuar." -ForegroundColor Yellow
    $ok=Read-Host "Digite REMOVER para confirmar"
    if($ok -ne "REMOVER"){ Write-Host "Cancelado."; return }

    # Remove versões Click-to-Run. RemoveMSI cobre instalações MSI antigas durante a implantação.
    $xml=@"
<Configuration>
  <Remove All="TRUE" />
  <Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
"@
    $cfg=Write-Xml "remove.xml" $xml
    Run-ODT $cfg
    Write-OK "Remoção solicitada/concluída pela ODT."
}

function Install-Office2024 {
    Download-ODT
    $arch=if([Environment]::Is64BitOperatingSystem){"64"}else{"32"}

    $xml=@"
<Configuration>
  <Add OfficeClientEdition="$arch" Channel="PerpetualVL2024">
    <Product ID="ProPlus2024Volume">
      <Language ID="pt-br" />
    </Product>
  </Add>
  <RemoveMSI />
  <Display Level="Full" AcceptEULA="TRUE" />
  <Updates Enabled="TRUE" />
</Configuration>
"@
    $cfg=Write-Xml "install2024.xml" $xml
    Write-Host "[+] Instalando Office LTSC Professional Plus 2024 ($arch-bit)..." -ForegroundColor Cyan
    Write-Host "[i] A licença precisa ser compatível com a edição instalada." -ForegroundColor Yellow
    Run-ODT $cfg
    Write-OK "Instalação concluída."
}

function Install-M365 {
    Download-ODT
    $arch=if([Environment]::Is64BitOperatingSystem){"64"}else{"32"}

    $xml=@"
<Configuration>
  <Add OfficeClientEdition="$arch">
    <Product ID="O365ProPlusRetail">
      <Language ID="pt-br" />
    </Product>
  </Add>
  <RemoveMSI />
  <Display Level="Full" AcceptEULA="TRUE" />
  <Updates Enabled="TRUE" />
</Configuration>
"@
    $cfg=Write-Xml "install365.xml" $xml
    Write-Host "[+] Instalando Microsoft 365 Apps ($arch-bit)..." -ForegroundColor Cyan
    Run-ODT $cfg
    Write-OK "Instalação concluída. A ativação normalmente é feita pela conta/licença do cliente."
}

function Repair-Office {
    $exe=@(
      "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe",
      "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    ) | Where-Object {$_ -and (Test-Path $_)} | Select-Object -First 1
    if(-not $exe){ Write-Host "[!] Componente de reparo não encontrado." -ForegroundColor Yellow; return }
    $platform=if([Environment]::Is64BitOperatingSystem){'x64'}else{'x86'}
    Start-Process $exe -ArgumentList "scenario=Repair platform=$platform culture=pt-br" -Wait
    Write-OK "Reparo executado."
}

function Status {
    Write-Section "STATUS DO OFFICE"
    $ospp=@(
      "$env:ProgramFiles\Microsoft Office\Office16\OSPP.VBS",
      "${env:ProgramFiles(x86)}\Microsoft Office\Office16\OSPP.VBS"
    ) | Where-Object {$_ -and (Test-Path $_)} | Select-Object -First 1
    if($ospp){ cscript.exe //nologo $ospp /dstatus } else { Write-Host "OSPP não encontrado; pode ser Microsoft 365 ou outra tecnologia." }
    Write-Section "STATUS DO WINDOWS"
    cscript.exe //nologo "$env:WINDIR\System32\slmgr.vbs" /xpr
}

function Activate-Key {
    $ospp=@(
      "$env:ProgramFiles\Microsoft Office\Office16\OSPP.VBS",
      "${env:ProgramFiles(x86)}\Microsoft Office\Office16\OSPP.VBS"
    ) | Where-Object {$_ -and (Test-Path $_)} | Select-Object -First 1
    if(-not $ospp){ Write-Host "[!] OSPP não encontrado." -ForegroundColor Yellow; return }
    $key=Read-Host "Digite a chave válida do Office (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)"
    if($key -notmatch '^[A-Za-z0-9]{5}(-[A-Za-z0-9]{5}){4}$'){ throw "Formato de chave inválido." }
    cscript.exe //nologo $ospp /inpkey:$key
    cscript.exe //nologo $ospp /act
    Status
}

function Full-Flow {
    Write-Section "FLUXO AUTOMÁTICO LINKON"
    if(-not (Test-Net)){ throw "Sem internet. O fluxo automático precisa de internet para baixar a ODT e o Office." }

    Write-Section "ETAPA 1/4 • DIAGNÓSTICO"
    Get-OfficeProducts

    Write-Section "ETAPA 2/4 • REMOÇÃO"
    $ok=Read-Host "Digite SIM para remover o Office existente e continuar"
    if($ok -eq "SIM"){
        Download-ODT
        $xml=@"
<Configuration>
  <Remove All="TRUE" />
  <Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
"@
        $cfg=Write-Xml "remove-flow.xml" $xml
        Run-ODT $cfg
        Start-Sleep -Seconds 3
    } else {
        Write-Host "Fluxo cancelado para evitar conflito entre instalações." -ForegroundColor Yellow
        return
    }

    Write-Section "ETAPA 3/4 • INSTALAÇÃO"
    Install-Office2024

    Write-Section "ETAPA 4/4 • VERIFICAÇÃO"
    Status
    Write-OK "Fluxo LinkOn finalizado."
}

function Start-LinkOnGUI {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $bg = [System.Drawing.ColorTranslator]::FromHtml('#070012')
    $panel = [System.Drawing.ColorTranslator]::FromHtml('#12051B')
    $panel2 = [System.Drawing.ColorTranslator]::FromHtml('#1B0824')
    $pink = [System.Drawing.ColorTranslator]::FromHtml('#F80677')
    $pinkDark = [System.Drawing.ColorTranslator]::FromHtml('#4F0837')
    $white = [System.Drawing.Color]::White
    $muted = [System.Drawing.ColorTranslator]::FromHtml('#B9A7B8')
    $cyan = [System.Drawing.ColorTranslator]::FromHtml('#35D9FF')
    $green = [System.Drawing.ColorTranslator]::FromHtml('#42E695')
    $yellow = [System.Drawing.ColorTranslator]::FromHtml('#FFD166')

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "LINKON • OFFICE TOOL v$($Brand.Version)"
    $form.Size = New-Object System.Drawing.Size(1060,720)
    $form.MinimumSize = New-Object System.Drawing.Size(980,650)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = $bg
    $form.ForeColor = $white
    $form.Font = New-Object System.Drawing.Font('Segoe UI',10)

    $header = New-Object System.Windows.Forms.Panel
    $header.Dock='Top'; $header.Height=118; $header.BackColor=$panel
    $form.Controls.Add($header)

    $logoText = New-Object System.Windows.Forms.Label
    $logoText.Text='LINKON'; $logoText.AutoSize=$true; $logoText.Location=New-Object System.Drawing.Point(30,18)
    $logoText.Font=New-Object System.Drawing.Font('Segoe UI',28,[System.Drawing.FontStyle]::Bold); $logoText.ForeColor=$pink
    $header.Controls.Add($logoText)
    $product = New-Object System.Windows.Forms.Label
    $product.Text="OFFICE TOOL  •  v$($Brand.Version)"; $product.AutoSize=$true; $product.Location=New-Object System.Drawing.Point(34,66)
    $product.Font=New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold); $product.ForeColor=$white
    $header.Controls.Add($product)
    $tag = New-Object System.Windows.Forms.Label
    $tag.Text='ATENDIMENTO  •  DIAGNÓSTICO  •  INSTALAÇÃO  •  REPARO'; $tag.AutoSize=$true; $tag.Location=New-Object System.Drawing.Point(360,44)
    $tag.Font=New-Object System.Drawing.Font('Segoe UI',10); $tag.ForeColor=$cyan
    $header.Controls.Add($tag)
    $line=New-Object System.Windows.Forms.Panel; $line.Location=New-Object System.Drawing.Point(0,114); $line.Size=New-Object System.Drawing.Size(1060,4); $line.BackColor=$pink
    $header.Controls.Add($line)

    $left=New-Object System.Windows.Forms.Panel; $left.Location=New-Object System.Drawing.Point(25,140); $left.Size=New-Object System.Drawing.Size(660,500); $left.BackColor=$bg
    $form.Controls.Add($left)
    $right=New-Object System.Windows.Forms.Panel; $right.Location=New-Object System.Drawing.Point(710,140); $right.Size=New-Object System.Drawing.Size(315,500); $right.BackColor=$panel
    $form.Controls.Add($right)

    $menuTitle=New-Object System.Windows.Forms.Label; $menuTitle.Text='MENU PRINCIPAL'; $menuTitle.Location=New-Object System.Drawing.Point(8,0); $menuTitle.AutoSize=$true
    $menuTitle.Font=New-Object System.Drawing.Font('Segoe UI',14,[System.Drawing.FontStyle]::Bold); $menuTitle.ForeColor=$white; $left.Controls.Add($menuTitle)
    $sub=New-Object System.Windows.Forms.Label; $sub.Text='Ferramentas de suporte e implantação'; $sub.Location=New-Object System.Drawing.Point(9,32); $sub.AutoSize=$true; $sub.ForeColor=$muted; $left.Controls.Add($sub)

    $status=New-Object System.Windows.Forms.TextBox
    $status.Multiline=$true; $status.ReadOnly=$true; $status.ScrollBars='Vertical'; $status.BackColor=[System.Drawing.Color]::FromArgb(10,3,16); $status.ForeColor=$white
    $status.BorderStyle='FixedSingle'; $status.Font=New-Object System.Drawing.Font('Consolas',9); $status.Location=New-Object System.Drawing.Point(8,300); $status.Size=New-Object System.Drawing.Size(640,190)
    $left.Controls.Add($status)

    function Add-Log([string]$text,[string]$kind='INFO') {
        $stamp=Get-Date -Format 'HH:mm:ss'
        $status.AppendText("[$stamp] [$kind] $text`r`n")
        $status.SelectionStart=$status.TextLength; $status.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    function Invoke-Action([string]$name,[scriptblock]$action) {
        Add-Log $name 'AÇÃO'
        try { & $action | Out-String | ForEach-Object { if($_.Trim()){ Add-Log $_.Trim() } }; Add-Log 'Operação concluída.' 'OK' }
        catch { Add-Log $_.Exception.Message 'ERRO'; [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'LINKON • Erro','OK','Error') | Out-Null }
    }

    function Make-Button([string]$text,[int]$x,[int]$y,[scriptblock]$action,[bool]$accent=$false) {
        $b=New-Object System.Windows.Forms.Button; $b.Text=$text; $b.Location=New-Object System.Drawing.Point($x,$y); $b.Size=New-Object System.Drawing.Size(315,70)
        $b.FlatStyle='Flat'; $b.FlatAppearance.BorderSize=1; $b.FlatAppearance.BorderColor=if($accent){$pink}else{$pinkDark}
        $b.BackColor=if($accent){$pinkDark}else{$panel2}; $b.ForeColor=$white
        $b.Font=New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold); $b.Cursor='Hand'
        $b.Add_MouseEnter({ param($sender,$e) $sender.BackColor=$pinkDark; $sender.ForeColor=$white })
        $b.Add_MouseLeave({ param($sender,$e) $sender.BackColor=$panel2; $sender.ForeColor=$white })
        $b.Add_Click({ & $action })
        $left.Controls.Add($b); return $b
    }

    Make-Button '⚡  ATENDIMENTO AUTOMÁTICO' 8 60 { Invoke-Action 'Atendimento automático' { Full-Flow } } $true | Out-Null
    Make-Button '🔍  DIAGNÓSTICO DO OFFICE' 335 60 { Invoke-Action 'Diagnóstico' { Get-OfficeProducts } } | Out-Null
    Make-Button '📦  INSTALAR OFFICE LTSC 2024' 8 140 { Invoke-Action 'Instalação Office LTSC 2024' { Install-Office2024 } } | Out-Null
    Make-Button '☁  INSTALAR MICROSOFT 365' 335 140 { Invoke-Action 'Instalação Microsoft 365' { Install-M365 } } | Out-Null
    Make-Button '🔧  REPARAR OFFICE' 8 220 { Invoke-Action 'Reparo Office' { Repair-Office } } | Out-Null
    Make-Button '🗑  REMOVER OFFICE ANTIGO' 335 220 { 
        if([System.Windows.Forms.MessageBox]::Show('A remoção desinstala os produtos Office detectados. Deseja continuar?','LINKON • Remover Office','YesNo','Warning') -eq 'Yes'){ Invoke-Action 'Remoção do Office' { Remove-Office } }
    } | Out-Null

    $rightTitle=New-Object System.Windows.Forms.Label; $rightTitle.Text='STATUS DO AMBIENTE'; $rightTitle.Location=New-Object System.Drawing.Point(20,20); $rightTitle.AutoSize=$true; $rightTitle.Font=New-Object System.Drawing.Font('Segoe UI',13,[System.Drawing.FontStyle]::Bold); $rightTitle.ForeColor=$white; $right.Controls.Add($rightTitle)
    $envBox=New-Object System.Windows.Forms.Label; $envBox.Location=New-Object System.Drawing.Point(20,60); $envBox.Size=New-Object System.Drawing.Size(275,150); $envBox.ForeColor=$muted; $envBox.Font=New-Object System.Drawing.Font('Consolas',9); $right.Controls.Add($envBox)
    function Refresh-Environment {
        $os=Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue; $cs=Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        $arch=if([Environment]::Is64BitOperatingSystem){'x64'}else{'x86'}; $net=if(Test-Net){'ONLINE'}else{'OFFLINE'}
        $osName=if($os){$os.Caption}else{'Windows'}; $ram=if($cs){'{0:N1} GB' -f ($cs.TotalPhysicalMemory/1GB)}else{'-'}
        $envBox.Text="PC          $env:COMPUTERNAME`r`nWINDOWS     $osName`r`nARQUITETURA $arch`r`nMEMÓRIA     $ram`r`nINTERNET    $net"
        $envBox.ForeColor=if($net -eq 'ONLINE'){$green}else{$yellow}
    }
    Refresh-Environment

    $toolsTitle=New-Object System.Windows.Forms.Label; $toolsTitle.Text='AÇÕES RÁPIDAS'; $toolsTitle.Location=New-Object System.Drawing.Point(20,230); $toolsTitle.AutoSize=$true; $toolsTitle.Font=New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold); $toolsTitle.ForeColor=$pink; $right.Controls.Add($toolsTitle)
    $bStatus=New-Object System.Windows.Forms.Button; $bStatus.Text='✓  VERIFICAR OFFICE / WINDOWS'; $bStatus.Location=New-Object System.Drawing.Point(20,265); $bStatus.Size=New-Object System.Drawing.Size(275,48); $bStatus.FlatStyle='Flat'; $bStatus.BackColor=$panel2; $bStatus.ForeColor=$white; $bStatus.FlatAppearance.BorderColor=$pinkDark; $bStatus.Add_Click({ Invoke-Action 'Status' { Status } }); $right.Controls.Add($bStatus)
    $bKey=New-Object System.Windows.Forms.Button; $bKey.Text='🔑  ATIVAR COM CHAVE VÁLIDA'; $bKey.Location=New-Object System.Drawing.Point(20,325); $bKey.Size=New-Object System.Drawing.Size(275,48); $bKey.FlatStyle='Flat'; $bKey.BackColor=$panel2; $bKey.ForeColor=$white; $bKey.FlatAppearance.BorderColor=$pinkDark; $bKey.Add_Click({ Invoke-Action 'Ativação por chave' { Activate-Key } }); $right.Controls.Add($bKey)
    $bOdt=New-Object System.Windows.Forms.Button; $bOdt.Text='↓  BAIXAR / ATUALIZAR ODT'; $bOdt.Location=New-Object System.Drawing.Point(20,385); $bOdt.Size=New-Object System.Drawing.Size(275,48); $bOdt.FlatStyle='Flat'; $bOdt.BackColor=$panel2; $bOdt.ForeColor=$white; $bOdt.FlatAppearance.BorderColor=$pinkDark; $bOdt.Add_Click({ Invoke-Action 'ODT oficial' { Download-ODT } }); $right.Controls.Add($bOdt)
    $footer=New-Object System.Windows.Forms.Label; $footer.Text='Licenciamento: use somente chaves/licenças válidas.'; $footer.Location=New-Object System.Drawing.Point(20,450); $footer.Size=New-Object System.Drawing.Size(275,40); $footer.ForeColor=$muted; $footer.Font=New-Object System.Drawing.Font('Segoe UI',8); $right.Controls.Add($footer)

    Add-Log 'LinkOn Office Tool iniciado.' 'OK'
    Add-Log 'Interface gráfica carregada.' 'INFO'
    $form.Add_Shown({ $form.Activate() })
    [void]$form.ShowDialog()
}

try {
    Start-LinkOnGUI
} finally {
    Stop-Transcript | Out-Null
}
