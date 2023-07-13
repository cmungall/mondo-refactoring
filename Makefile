SRC = ../mondo-edit.obo
DB = mondo.db
SRC_DB_PATH = $(HOME)/.data/oaklib/mondo.db

all: refactored-normalized.obo

load-views: views.sql
	cat views.sql | sqlite3 $(DB) 

link:
	ln -s $(SRC_DB_PATH) $(DB)

candidates.tsv: views.sql
	runoak -i $(DB) query -q "SELECT DISTINCT id FROM obsoletion_candidate ORDER BY id" -o $@

refactored.obo: $(SRC) candidates.tsv views.sql
	runoak --stacktrace -i simpleobo:$< apply-obsolete --ignore-invalid-changes [ .idfile candidates.tsv .idfile candidates-curated.txt ] .not .idfile rescue-curated.txt -o $@.tmp && egrep -v 'relationship: excluded_subClassOf .*Rewired from link to' $@.tmp | egrep -v 'is_a: MONDO:0000001 {description="Rewired from link' > $@

refactored-normalized.obo: refactored.obo
	robot convert -i $< -o $@

is-a-candidates.tsv:
	runoak -i $(DB) query -q "SELECT DISTINCT * FROM ordo_is_a_candidate ORDER BY subject, object, preferred_object" -o $@
