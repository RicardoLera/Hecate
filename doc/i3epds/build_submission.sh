#! /bin/bash

# Submission guidelines: "You may bundle LaTeX manuscript files in a single archive including all LaTeX files, BibTeX files, figures, tables, all LaTeX classes and packages, and any other material that belongs to your main manuscript"

# Before submitting, test with https://latexqc.ieee.org/

# Later submit to https://www.techrxiv.org/, as it is explicitly allowed by IEEE

# peer-review archive
cp peer_review.tex anonymized_main_document.tex
zip -FSr submission/anonymized_main_document \
  anonymized_main_document.tex \
  packages.tex \
  abstract.tex \
  body.tex \
  references.bib \
  fig/tikz.tex \
  fig/*0.pdf \
  fig/*1.pdf
rm anonymized_main_document.tex

# peer-review PDF
cp peer_review.pdf submission/anonymized_main_document.pdf

# title page (yes it needs to be in word format, blame IEEE)
pandoc title_page.tex -o submission/title_page.docx