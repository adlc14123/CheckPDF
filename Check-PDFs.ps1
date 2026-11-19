# ==============================================================================
# Script: Check-PDFs.ps1
# Descrição: Valida a integridade de todos os arquivos PDF (recursivamente)
#            utilizando o GNU Ghostscript (gswin64c) e contabiliza o total de páginas.
# Configuração de codificação: UTF-8 com BOM
# ==============================================================================

# Força o console do PowerShell a utilizar UTF-8 para exibição
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Determina o diretório onde o script está localizado
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$OutputFile = Join-Path -Path $ScriptDir -ChildPath "CheckPDFoutput.txt"

# Inicializa/limpa o arquivo de log para a nova execução
"" | Out-File -FilePath $OutputFile -Encoding utf8

# Função para registrar mensagens simultaneamente no terminal e no arquivo de log
function Write-Log {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $OutputFile -Value $Message -Encoding utf8
}

# Registra o horário de início
$StartTime = Get-Date
Write-Log "=================================================================" "Cyan"
Write-Log " INÍCIO DA VERIFICAÇÃO DE INTEGRIDADE DE PDFs" "Cyan"
Write-Log " Horário de início: $($StartTime.ToString('dd/MM/yyyy HH:mm:ss'))" "Cyan"
Write-Log "=================================================================" "Cyan"
Write-Log ""

# Obtém recursivamente todos os arquivos PDF a partir do diretório corrente
$pdfFiles = @(Get-ChildItem -Path . -Filter "*.pdf" -Recurse -File)
$totalFiles = $pdfFiles.Count
$okCount = 0
$corruptCount = 0
$totalPages = 0

Write-Log "Total de arquivos PDF encontrados: $totalFiles" "Yellow"
Write-Log "Processando arquivos..." "Yellow"
Write-Log "-----------------------------------------------------------------"

# Função de fallback para obter páginas via Ghostscript (-dNOSAFER ativado)
function Get-PdfPageCount {
    param ([string]$FilePath)
    try {
        # Escapa caracteres especiais para a string em formato PostScript
        $psPath = $FilePath.Replace('\', '/').Replace('(', '\(').Replace(')', '\)')
        $cmd = "($psPath) (r) file runpdfbegin pdfpagecount = quit"
        $output = & gswin64c -q -dNODISPLAY -dNOSAFER -dBATCH -dNOPAUSE -c $cmd 2>$null
        
        $pageStr = ($output | Where-Object { $_ -match '^\d+$' }) | Select-Object -Last 1
        if ($pageStr) {
            return [int]$pageStr
        }
        return 0
    } catch {
        return 0
    }
}

$currentIndex = 0

foreach ($file in $pdfFiles) {
    $currentIndex++
    # Caminho relativo para exibição limpa no console
    $relativePath = Resolve-Path -Path $file.FullName -Relative
    
    Write-Log "[$currentIndex/$totalFiles] Testando: $relativePath" "Gray"
    
    # Executa o Ghostscript no modo nullpage (sem -q para emitir o progresso de páginas "Page X")
    $gsOutput = & gswin64c -dBATCH -dNOPAUSE -dNODISPLAY -sDEVICE=nullpage "$($file.FullName)" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        # Extrai a contagem de páginas da saída da renderização (linhas "Page 1", "Page 2"...)
        $pageMatches = @($gsOutput | Where-Object { $_ -match '^Page \d+' })
        $filePages = $pageMatches.Count
        
        # Se a saída não capturou as páginas, chama a função de fallback
        if ($filePages -eq 0) {
            $filePages = Get-PdfPageCount -FilePath $file.FullName
        }
        
        $totalPages += $filePages
        Write-Log "   -> Status: OK | Páginas: $filePages" "Green"
        $okCount++
    } else {
        Write-Log "   -> Status: CORROMPIDO (Código de erro: $LASTEXITCODE)" "Red"
        $corruptCount++
    }
}

# Registra o horário de conclusão e calcula a duração total
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

# Formata o tempo decorrido no formato HH:mm:ss
$totalHours = [int][math]::Floor($Duration.TotalHours)
$totalMinutes = [int]$Duration.Minutes
$totalSeconds = [int]$Duration.Seconds
$formattedDuration = "{0:D2}:{1:D2}:{2:D2}" -f $totalHours, $totalMinutes, $totalSeconds

Write-Log ""
Write-Log "=================================================================" "Cyan"
Write-Log " RESUMO FINAL DA EXECUÇÃO" "Cyan"
Write-Log "=================================================================" "Cyan"
Write-Log " Horário de início   : $($StartTime.ToString('dd/MM/yyyy HH:mm:ss'))"
Write-Log " Horário de conclusão: $($EndTime.ToString('dd/MM/yyyy HH:mm:ss'))"
Write-Log " Tempo de execução   : $formattedDuration (HH:mm:ss)"
Write-Log " ---------------------------------------------------------------"
Write-Log " Total de PDFs testados : $totalFiles"
Write-Log " PDFs íntegros (OK)     : $okCount" "Green"
Write-Log " PDFs corrompidos       : $corruptCount" $(if ($corruptCount -gt 0) { "Red" } else { "Green" })
Write-Log " Total de páginas (OK)  : $totalPages" "Yellow"
Write-Log "=================================================================" "Cyan"
Write-Log " Relatório salvo em: $OutputFile" "Yellow"