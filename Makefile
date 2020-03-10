
all: mysql-notes.pdf

mysql-notes.tex: mysql-notes.txt
	rst2latex.py mysql-notes.txt  > mysql-notes.tex

mysql-notes.pdf: mysql-notes.tex
	pdflatex mysql-notes.tex

clean:
	rm -f *.tex *.aux *.log *.pdf
