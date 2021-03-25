%.csv: %.sql
	psql -Upostgres -q -h0.0.0.0 -p5432 uk_tariff --csv < $< > $@

data.sqlite: schema.sql commodity_codes.csv indents.csv
	sqlite3 $@ -echo < schema.sql && \
	sqlite3 $@ -echo -csv ".import commodity_codes.csv commodity_codes" && \
	sqlite3 $@ -echo -csv ".import indents.csv indents"

challenge.tar.gz: README.md data.sqlite reference.csv
	tar -czvf $@ $^
