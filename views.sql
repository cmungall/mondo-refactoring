-- is_a is subClassOf between NCs
CREATE VIEW is_a AS
 SELECT * FROM rdfs_subclass_of_statement
 WHERE object NOT LIKE '_:%';

-- ORDO equivs
DROP VIEW IF EXISTS mondo_with_ordo;
CREATE VIEW mondo_with_ordo AS
 SELECT DISTINCT subject AS id
 FROM has_dbxref_statement
 WHERE value LIKE 'Orphanet:%' AND subject LIKE 'MONDO:%';
 
-- OMIM equivs
CREATE VIEW mondo_with_omim AS
 SELECT subject AS id
 FROM has_dbxref_statement
 WHERE value LIKE 'OMIM:%' AND subject LIKE 'MONDO:%';

-- proper is-a ancestor of a omim equiv
DROP VIEW IF EXISTS mondo_omim_ancestor;
CREATE VIEW mondo_omim_ancestor AS
 SELECT object AS id
 FROM
  entailed_edge
 WHERE
  predicate = 'rdfs:subClassOf' AND
  subject IN (SELECT id FROM mondo_with_omim) AND
  subject != object;
 
-- class that is supported by ordo only 
CREATE VIEW ordo_only AS
 SELECT id
 FROM mondo_with_ordo
 WHERE
  id NOT IN (SELECT subject FROM has_dbxref_statement WHERE value NOT LIKE 'Orphanet:%' AND value NOT LIKE 'UMLS:%') AND
  id NOT IN (SELECT id FROM deprecated_node);

CREATE VIEW in_subset AS
 SELECT * FROM statements WHERE predicate='oio:inSubset';

CREATE VIEW clingen AS
 SELECT subject AS id
 FROM in_subset WHERE object like '%clingen';

CREATE VIEW ordo_group_of_disorders AS
 SELECT subject AS id
 FROM in_subset WHERE object like '%ordo_group_of_disorders';

-- supported def
DROP VIEW IF EXISTS def_annotation;
CREATE VIEW def_annotation AS
 SELECT *
 FROM owl_axiom_annotation
 WHERE
  predicate='IAO:0000115';

DROP VIEW IF EXISTS non_ordo_def_annotation;
CREATE VIEW non_ordo_def_annotation AS
 SELECT *
 FROM def_annotation
 WHERE annotation_value NOT LIKE 'Orphanet:%';

DROP VIEW IF EXISTS non_ordo_or_self_def_annotation;
CREATE VIEW non_ordo_or_self_def_annotation AS
 SELECT *
 FROM def_annotation
 WHERE annotation_value NOT LIKE 'Orphanet:%' AND annotation_value NOT LIKE 'MONDO:%';


-- rescue anything
-- (1) marked as clingen
-- (2) that has a non-trivial non-ordo definition annotation
CREATE VIEW rescue AS
 SELECT DISTINCT id
 FROM clingen
 UNION
 SELECT DISTINCT subject AS id
 FROM non_ordo_or_self_def_annotation;


-- obsolete is ordo only AND an omim anc
DROP VIEW IF EXISTS obsoletion_candidate;
CREATE VIEW obsoletion_candidate AS
 SELECT id
 FROM
  ordo_only
 WHERE
  ( id IN (SELECT id FROM mondo_omim_ancestor)
    OR
    id IN (SELECT id FROM ordo_group_of_disorders)
  )
  AND
  id NOT IN (SELECT id FROM rescue);




-- supported is-a
DROP VIEW IF EXISTS is_a_annotation;
CREATE VIEW is_a_annotation AS
 SELECT *
 FROM owl_axiom_annotation
 WHERE
  predicate='rdfs:subClassOf' AND
  object LIKE 'MONDO:%';

-- is-a with source (view)
CREATE VIEW is_a_source_view AS
 SELECT *
 FROM is_a_annotation
 WHERE annotation_predicate = 'oio:source';

-- (materialized for speed)
CREATE TABLE is_a_source AS
 SELECT * FROM is_a_source_view;

-- an is-a supported (in whole or part) by ordo
DROP VIEW IF EXISTS ordo_is_a;
CREATE VIEW ordo_is_a AS
 SELECT *
 FROM is_a_source
 WHERE annotation_value LIKE 'Orphanet:%';

CREATE VIEW non_ordo_is_a AS
 SELECT *
 FROM is_a_source
 WHERE annotation_value NOT LIKE 'Orphanet:%';

-- an is-a supported only by ordo
CREATE VIEW sole_ordo_is_a AS
 SELECT *
 FROM ordo_is_a AS e1
 WHERE NOT EXISTS (SELECT subject,object FROM is_a_source AS e2 WHERE e1.subject=e2.subject AND e1.object=e2.object AND annotation_value NOT LIKE 'Orphanet:%');

-- candidate for is-a removal
DROP VIEW IF EXISTS ordo_is_a_candidate;
CREATE VIEW ordo_is_a_candidate AS
 SELECT DISTINCT e1.subject, e1.object, e1.annotation_value AS ordo_id, e2.object AS preferred_object, e2.annotation_value AS preferred_edge_source
 FROM
  sole_ordo_is_a AS e1,
  non_ordo_is_a AS e2
 WHERE
  e2.subject=e1.subject AND e2.object != e1.object AND
  e1.object NOT IN (SELECT id FROM ordo_only);
 
