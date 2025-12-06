# scripts/README

This folder contains a convenience PowerShell script to convert `results/thesis2.md` into a PDF with images and LaTeX math rendered.

Files:
- `convert_md_to_pdf.ps1` — PowerShell script that:
  - Activates the conda env `ultralytics-thesis`.
  - Checks for `pandoc` and a LaTeX engine (`xelatex`/`pdflatex`) and attempts to install them via `conda` if missing.
  - Runs `pandoc` to create `results/thesis2.pdf`.

Usage (PowerShell):

```powershell
cd "d:\projects\git-hub\Ultralytics - masters\ultralytics"
./scripts/convert_md_to_pdf.ps1
```

Notes and alternatives:
- Installing TeX via conda can be large. If you prefer to install manually use:
  - Install `pandoc` from https://pandoc.org/installing.html
  - Install a TeX distribution (e.g., TeX Live or MikTeX) so that `xelatex`/`pdflatex` is available on PATH.
- If you don't want to install a TeX engine, another route is to convert to HTML with pandoc and then print/save as PDF from a browser, or use `wkhtmltopdf`.

If you want me to run the script now and attempt to produce `results/thesis2.pdf`, tell me and I'll execute it.