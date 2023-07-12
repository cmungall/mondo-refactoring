SRC = ../mondo-edit.obo
DB = sqlite:obo:mondo
DB_PATH = $(HOME)/.data/oaklib/mondo.db

load-views: views.sql
	cat views.sql | sqlite3 $(DB_PATH) 

candidates.tsv:
	runoak -i $(DB) query -q "SELECT DISTINCT id FROM obsoletion_candidate ORDER BY id" -o $@

refactored.obo: $(SRC) candidates.tsv
	runoak --stacktrace -i simpleobo:$< apply-obsolete --ignore-invalid-changes [ .idfile candidates.tsv .idfile candidates-curated.txt ] .not .idfile rescue-curated.txt -o $@.tmp && egrep -v 'relationship: excluded_subClassOf .*Rewired from link to' $@.tmp > $@

refactored-normalized.obo: refactored.obo
	robot convert -i $< -o $@

is-a-candidates.tsv:
	runoak -i $(DB) query -q "SELECT * FROM ordo_is_a_candidate"
