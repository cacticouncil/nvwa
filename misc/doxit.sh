#! /bin/sh

# Recommended tool versions and notes:
#
#   * Graphviz 2.38
#
#     This new version works well for me
#
#   * Doxygen 1.5.1/1.5.2 for LaTeX output
#
#     1.5.3+ have wrong output in some diagrams
#
#   * Doxygen 1.5.8/1.6.2/1.8.10 for HTML output 
#
#     1.5.9 has broken link on "More..."
#     1.6.0/1 left-aligns the project name
#     1.6.3 has issues with included-by graphs
#
#     I personally do not quite like the look of output of 1.8, but it
#     has good support for C++11
#

# Intermediate Doxyfile
DOXYFILE_TMP=nvwa.dox

# Whether/how to generate LaTeX documents
if [ "$1" = "latex" ]; then
  GENERATE_LATEX=YES
elif [ "$1" = "ps" ]; then
  GENERATE_LATEX=YES
  PDF_HYPERLINKS=NO
  USE_PDFLATEX=NO
elif [ "$1" = "pdf" ]; then
  GENERATE_LATEX=YES
  PDF_HYPERLINKS=YES
  USE_PDFLATEX=YES
elif [ "$1" = "pdf2" ]; then
  GENERATE_LATEX=YES
  PDF_HYPERLINKS=YES
  USE_PDFLATEX=NO
fi

# Determine the Doxygen engine
if [ "$DOXYGEN" = "" ]; then
  DOXYGEN=doxygen
fi

HIDE_FUNCTIONAL_H=NO
$DOXYGEN --version | grep '^1\.\(5\|6\)\.' > /dev/null && HIDE_FUNCTIONAL_H=YES

# Determine Doxygen options
if [ "$PDF_HYPERLINKS" = "" ]; then
  PDF_HYPERLINKS=NO
fi
if [ "$USE_PDFLATEX" = "" ]; then
  USE_PDFLATEX=NO
fi
if [ "$GENERATE_LATEX" = "" ]; then
  if [ "$PDF_HYPERLINKS" = "YES" ]; then
    GENERATE_LATEX=YES
  elif [ "$USE_PDFLATEX" = "YES" ]; then
    GENERATE_LATEX=YES
  else
    GENERATE_LATEX=NO
  fi
fi

# Set the options in the intermediate Doxyfile
cp -p Doxyfile $DOXYFILE_TMP
if [ "$GENERATE_LATEX" = "YES" ]; then
  sedfile 's/\(GENERATE_LATEX *=\).*/\1 YES/' $DOXYFILE_TMP
  if [ "$PDF_HYPERLINKS" = "YES" ]; then
    sedfile 's/\(PDF_HYPERLINKS *=\).*/\1 YES/' $DOXYFILE_TMP
  else
    sedfile 's/\(PDF_HYPERLINKS *=\).*/\1 NO/'  $DOXYFILE_TMP
  fi
  if [ "$USE_PDFLATEX" = "YES" ]; then
    sedfile 's/\(USE_PDFLATEX *=\).*/\1 YES/' $DOXYFILE_TMP
  else
    sedfile 's/\(USE_PDFLATEX *=\).*/\1 NO/'  $DOXYFILE_TMP
  fi
else
  sedfile 's/\(GENERATE_LATEX *=\).*/\1 NO/'  $DOXYFILE_TMP
fi
if [ "$HIDE_FUNCTIONAL_H" = "YES" ]; then
  sedfile 's/ \(.*nvwa\/functional\.h\)/#\1/' $DOXYFILE_TMP
fi

# Work around an expression that will confuse Doxygen
mv -i ../nvwa/static_mem_pool.h ..
sed 's/(_Gid < 0)/true/' ../static_mem_pool.h >../nvwa/static_mem_pool.h
$DOXYGEN $DOXYFILE_TMP
mv -f ../static_mem_pool.h ../nvwa/

# Remove the intermediate Doxyfile
rm $DOXYFILE_TMP

# Remove the space between -> and * in Doxygen pre-1.5.5 versions
cd ../doc/html
echo "Postprocessing HTML files"
grepsedfile 'operator-&gt; \*' 'operator-\&gt;*' *.html
cd ../../misc

# Make LaTeX documents
if [ "$GENERATE_LATEX" = "YES" ]; then
  cd ../doc/latex
  echo "Postprocessing LaTeX files"

  # Remove the URIs in EPS files
  for file in *.eps
  do
    echo "$file"
    ed -s <<!EOF "$file"
      g/\[ \/Rect/.,.+4d
      w
      q
!EOF
  done

  # The LaTeX output automatically changes the operator "->" to
  # "\rightarrow", which does not look right.
  grepsedfile 'operator \$\\rightarrow\$ *' 'operator->' *.tex
  grepsedfile '\$\\rightarrow\$ *' '->' *.tex

  # Note for non-PDFLaTeX output: the package cm-super should be
  # installed, which would make the PDF file contain only Type 1 and
  # TrueType fonts.
  if [ "$PDF_HYPERLINKS" = "NO" -a "$USE_PDFLATEX" = "NO" ]; then
    make clean ps
    ps2pdf -sPAPERSIZE=a4 refman.ps refman.pdf
  else
    if [ "$PDF_HYPERLINKS" = "YES" ]; then
      # Work around a bug in Doxygen 1.5.1 when PDF_HYPERLINKS=YES.
      # It is fixed in Doxygen 1.5.3, so the following line will be
      # commented out or removed in the future.
      grepsedfile '\(subsubsection\[[^]]*\)\[\]' '\1[\\mbox{]}' *.tex
    fi

    # USE_PDFLATEX=NO (option "pdf2") may not work the first time it is
    # run.  To work around this issue, run the script with the option
    # "pdf" first. -- This problem does not occur with more recent LaTeX
    # distributions like MiKTeX 2.7 or TeXLive 2008.
    rm -f refman.pdf
    make

    # Doxygen 1.5.1 has problems with "make refman.pdf" when
    # PDF_HYPERLINKS=YES and USE_PDFLATEX=NO, and must use the bare
    # "make", as shown above.  It is fixed in Doxygen 1.5.3, and the
    # following line is now necessary.
    [ -f refman.pdf ] || make refman.pdf
  fi
fi
