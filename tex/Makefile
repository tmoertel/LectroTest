
all : lectrotest.pdf
.PHONY : all

lectrotest.tex : ../lib/Test/LectroTest.pm ../lib/Test/LectroTest/Tutorial.pod ../lib/Test/LectroTest/Compat.pm ../lib/Test/LectroTest/Generator.pm ../lib/Test/LectroTest/Property.pm ../lib/Test/LectroTest/TestRunner.pm
	pod2latex -full -verbose -modify -out lectrotest $^
	perl -i -pe'print"%"if/^\\usepackage(?:\[T1\]|\{textcomp\})/;s/\"(?=\w)/\`\`/g if /^\S/; s/\\textit/\\emph/g;' -e'print q(\input{titlepage.ltx}).$$/ if /tableofcontents/' $@

%.pdf : %.tex
	pdflatex $< && pdflatex $<

clean:
	rm -rf lectrotest.*
