<#
Convert `results/thesis2.md` -> `results/thesis2.pdf` with images and LaTeX math.

Usage (PowerShell):
  1. Open PowerShell
  2. Run: `./scripts/convert_md_to_pdf.ps1`

Notes:
  - Script activates the conda env `ultralytics-thesis`.
  - If `pandoc` or `xelatex` aren't found, it attempts to install via conda-forge in the active env.
  - Installation of TeX can be large. If you prefer to avoid automatic installs, install `pandoc` and a TeX engine manually and re-run.
#>

param(
    [switch]$AsIs
)

Set-StrictMode -Version Latest

if ($AsIs) { Write-Host "Starting faithful (AsIs) Markdown -> PDF conversion for results/thesis2.md" } else { Write-Host "Starting Markdown -> PDF conversion for results/thesis2.md" }

# Ensure running from repository root (two levels up from scripts folder)
# compute results directory and switch to it (single push)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$resultsDirFull = Join-Path $scriptDir '..\results'
Push-Location $resultsDirFull

# Activate conda env
Write-Host "Activating conda environment 'ultralytics-thesis'..."
conda activate ultralytics-thesis

function Ensure-Command {
    param(
        [string]$Name,
        [scriptblock]$InstallCmd
    )
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Host "$Name not found. Attempting to install via conda-forge (may require internet and large downloads)..."
        & $InstallCmd
        $cmd = Get-Command $Name -ErrorAction SilentlyContinue
        if (-not $cmd) {
            throw "$Name still not found after attempted install. Install manually and re-run the script."
        }
    } else {
        Write-Host "$Name found: $($cmd.Source)"
    }
}

# Check/install pandoc
Ensure-Command -Name pandoc -InstallCmd { conda install -n ultralytics-thesis -c conda-forge pandoc -y }

# Determine available LaTeX engine
$latexEngine = $null
if (Get-Command xelatex -ErrorAction SilentlyContinue) { $latexEngine = 'xelatex' }
elseif (Get-Command pdflatex -ErrorAction SilentlyContinue) { $latexEngine = 'pdflatex' }
else {
    Write-Host "No LaTeX engine found on PATH (xelatex/pdflatex). Attempting to locate MiKTeX via where.exe and add to PATH for this session..."

    # Try to locate MiKTeX executables using where.exe (works even if not in PowerShell command cache)
    try {
        $xelatexPaths = & where.exe xelatex 2>$null
    } catch { $xelatexPaths = $null }
    try {
        $pdflatexPaths = & where.exe pdflatex 2>$null
    } catch { $pdflatexPaths = $null }

    $added = $false
    if ($xelatexPaths) {
        $first = $xelatexPaths | Select-Object -First 1
        $dir = Split-Path -Parent $first
        if (Test-Path $dir) {
            Write-Host "Prepending MiKTeX folder to PATH: $dir"
            $env:Path = "$dir;$env:Path"
            $latexEngine = 'xelatex'
            $added = $true
        }
    }
    if (-not $added -and $pdflatexPaths) {
        $first = $pdflatexPaths | Select-Object -First 1
        $dir = Split-Path -Parent $first
        if (Test-Path $dir) {
            Write-Host "Prepending MiKTeX folder to PATH: $dir"
            $env:Path = "$dir;$env:Path"
            $latexEngine = 'pdflatex'
            $added = $true
        }
    }

    if (-not $added) {
        Write-Host "MiKTeX executables not found by where.exe; trying common MiKTeX install locations..."

        $possible = @(
            "$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin\x64",
            "$env:LOCALAPPDATA\Programs\MiKTeX\miktex\bin",
            "C:\Program Files\MiKTeX\miktex\bin\x64",
            "C:\Program Files\MiKTeX\miktex\bin",
            "C:\Program Files (x86)\MiKTeX\miktex\bin\x64",
            "C:\Program Files (x86)\MiKTeX\miktex\bin"
        )

        foreach ($p in $possible) {
            if (Test-Path $p) {
                Write-Host "Found MiKTeX folder: $p - adding to PATH"
                $env:Path = "$p;$env:Path"
                # prefer xelatex if present
                if (Test-Path (Join-Path $p 'xelatex.exe')) { $latexEngine = 'xelatex'; $added = $true; break }
                if (Test-Path (Join-Path $p 'pdflatex.exe')) { $latexEngine = 'pdflatex'; $added = $true; break }
            }
        }

        if (-not $added) {
            Write-Host "Common locations not found either. Will produce an HTML fallback with MathJax if PDF conversion is not possible."
        }
    } else {
        Write-Host "MiKTeX path added to PATH for this session. LaTeX engine: $latexEngine"
    }
}

$resultsDir = "results"

$input = "thesis2.md"
$pdfOutput = "thesis2.pdf"
$htmlOutput = "thesis2.html"

if (-not (Test-Path $input)) {
    Pop-Location
    throw "Input file not found in results/: $input"
}

    if ($latexEngine) {
        Write-Host "Converting $input -> $pdfOutput with engine $latexEngine"

        if ($AsIs) {
            # Faithful mode: don't inject header-includes, TOC, numbering, or font overrides.
            $pandocArgs = @(
                $input,
                '-o', $pdfOutput,
                '--from', 'gfm+tex_math_dollars+yaml_metadata_block+raw_html',
                '--standalone',
                '--pdf-engine', $latexEngine
            )
        } else {
            $pandocArgs = @(
                $input,
                '-o', $pdfOutput,
                '--from', 'markdown+tex_math_dollars+yaml_metadata_block',
                '--standalone',
                '--toc',
                '--number-sections',
                '-V', 'geometry:margin=1in',
                '-V', 'papersize:a4',
                '-V', 'documentclass:article',
                '-V', 'fontsize=13pt',
                '-V', 'mainfont=Arial',
                '-V', "header-includes:\AtBeginDocument{\fontsize{13pt}{16pt}\selectfont}",
                '--pdf-engine', $latexEngine
            )
        }

        Write-Host "Running pandoc with args: $pandocArgs"
        & pandoc @pandocArgs

        if ($LASTEXITCODE -eq 0 -and (Test-Path $pdfOutput)) {
            Write-Host "PDF created successfully: $resultsDir/$pdfOutput"
            Pop-Location
            exit 0
        } else {
            Write-Host "Pandoc PDF conversion failed (exit code $LASTEXITCODE). Falling back to HTML output."
        }
    } else {
        Write-Host "No LaTeX engine available - will create HTML fallback with MathJax and self-contained resources."
    }

# Fallback: generate a self-contained HTML with MathJax (images inlined)
Write-Host "Generating HTML fallback $htmlOutput with MathJax"
$htmlArgs = @(
    $input,
    '-o', $htmlOutput,
    '--from', 'markdown+tex_math_dollars+yaml_metadata_block',
    '--standalone',
    '--mathjax',
    '--self-contained',
    '--toc',
    '--number-sections'
)

& pandoc @htmlArgs

if ($LASTEXITCODE -eq 0 -and (Test-Path $htmlOutput)) {
    Write-Host "HTML created successfully: $resultsDir/$htmlOutput"
    Write-Host "Open the HTML in a browser and print to PDF (or use headless Chrome) to obtain a PDF with rendered math and embedded images."
    Pop-Location
    exit 0
} else {
    Pop-Location
    throw "Pandoc failed to produce HTML as well (exit code $LASTEXITCODE). Check output above for errors."
}

Write-Host "Done."
