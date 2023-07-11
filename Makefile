SRC = ../mondo-edit.obo
DB = sqlite:obo:mondo

# conservative
mondo-ordo-only.obo: $(SRC)
	obo-grep.pl -r 'xref: Orphanet' $(SRC) | obo-grep.pl --neg -r is_obsolete - | obo-grep.pl --neg -r 'xref: ([A-NP-Z]|OMIM)' - > $@

# only filtered xrefs
mondo-ordo-only.tsv:
	runoak -i $(DB) query -q "SELECT DISTINCT subject FROM has_dbxref_statement WHERE value LIKE 'Orphanet:%' AND subject NOT IN (SELECT subject FROM has_dbxref_statement WHERE value NOT like 'Orphanet:%') AND subject LIKE 'MONDO:%' AND subject NOT IN (SELECT id FROM deprecated_node)" -O csv -o $@

mondo-omim-ancestors.tsv: $(SRC)
	runoak -i $(DB) ancestors -p i x^OMIM: -O csv -o $@

candidates.tsv: mondo-ordo-only.tsv mondo-omim-ancestors.tsv
	runoak -i $(DB) labels .idfile $< .and .idfile mondo-omim-ancestors.tsv -O csv -o $@

refactored.obo: $(SRC)
	runoak --stacktrace -i simpleobo:$< apply-obsolete --ignore-invalid-changes [ .idfile candidates.tsv .idfile candidates-curated.txt ] .not .idfile rescue-curated.txt -o $@ 

refactored-normalized.obo: refactored.obo
	robot convert -i $< -o $@
