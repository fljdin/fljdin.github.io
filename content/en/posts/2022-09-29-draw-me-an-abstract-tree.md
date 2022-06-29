---
title: "Draw me an (abstract) tree"
translationKey: draw-me-an-abstract-tree
slug: draw-me-an-abstract-tree
categories: [postgresql]
tags: [developpement]
date: 2022-06-29
draft: yes
---

> The parser stage creates a parse tree using only fixed rules about the syntactic
> structure of SQL. It does not make any lookups in the system catalogs, so there
> is no possibility to understand the detailed semantics of the requested operations.
> 
> (Documentation : [Transformation Process][1])

[1]: https://www.postgresql.org/docs/14/parser-stage.html#id-1.10.3.6.4

What is going on from a user sends his SQL query to getting back a data result?
This passionating question (by a limited amount of people, of course) has been
study by Stefan Simkovics during his [Master's Thesis][2] at Vienna University of 
Technology in 1998.

His remarquebable work was added in [official documentation][3] as "Overview of
PostgreSQL Internals", which is intended to share Simkovics' researchs in a
simplified way to reach a larger audience.

With this article, I'm trilled to share recent thoughts about an subelement of
these internals, the parser one. It relies on a similar approach to compiling by
using a advanced development pattern called [AST][4] (abstract syntax tree).

[2]: https://archive.org/details/Enhancement_of_the_ANSI_SQL_Implementation_of_PostgreSQL/
[3]: https://www.postgresql.org/docs/14/overview.html
[4]: https://en.wikipedia.org/wiki/Abstract_syntax_tree

<!--more-->

---

## From code to machine

Writing statement as a bunch of words, as we do with SQL, involves a need of
understanding this specific statement to the execution engine. A simple comparaison
is common language, when grammar rules enforce the order of adjectives, nouns and
pronouns so that two interlocutors can understand each other.

In computing, this process is called [compilation][5] and transforms code
instructions to their equivalent binary operations submitted to the machine. 
Since the dawn of computer sciences, a few software programs have been responsible
for analysing instructions, divided into several families:

[5]: https://en.wikipedia.org/wiki/Compiler

* [Lexical analysis][6] reads a sequence of keywords or _lexemes_ to match with
  internal tokens, detects spacing or comments. The most famous scanners are
  [Lex][7] and [Flex][8] (a open-source alternative to Lex);
* [Parsing][9] refers to the formal analysis of previous lexemes into its
  constituents, resulting in a parse tree showing their syntactic relation to
  each other. The main parsers are [Yacc][10] and [Bison][11] (a forward-compatible
  Yacc replacement);
* [Semantic analysis][12] gathers necessary semantic information for previous
  steps, including variable declaration or type checking.

[6]: https://en.wikipedia.org/wiki/Lexical_analysis
[7]: https://en.wikipedia.org/wiki/Lex_(software)
[8]: https://en.wikipedia.org/wiki/Flex_(lexical_analyser_generator)
[9]: https://en.wikipedia.org/wiki/Parsing
[10]: https://en.wikipedia.org/wiki/Yacc
[11]: https://en.wikipedia.org/wiki/GNU_Bison
[12]: https://en.wikipedia.org/wiki/Semantic_analysis_(compilers)

Compiling steps are scrupulously implemented in PostgreSQL when a SQL sentence
sent by a user need to be interpreted. The Simkovics' thesis tales a journey into
query parsing:

```sql
SELECT s.sname, se.pno
  FROM supplier s, sells se
 WHERE s.sno > 2 AND s.sno = se.sno;
```

Scanning step finds out every instruction's words and categorizes them into lexemes
(reserved keywords, identifiers, operators, literals). If any syntax misleading
is encoutered, like a coma before `FROM` keyword, query parsing is halt and an
explicit error message is throwd back to user:

```text
ERROR:  syntax error at or near "FROM"
LINE 2:   FROM supplier s, sells se
```

At the end, if parsed query is syntactically correct, a parse tree is built in
memory to link lexemes according to the grammar rules of the language. Thus, the
main node `SelectStmt` is composed by differents branches, like queried tables
under their `RangeVar` node stored as an array into `fromClause` attribute. The
same goes for the representation of columns and conditions through the `targetList` 
and `whereClause` nodes respectively.

![Parse tree representation](/img/en/2022-09-29-parse-tree-representation.png)

Our parse tree is passed to an upper step, called rewriting, responsible for
performing some optimizations and transformations to nodes and removing useless
leafs. Then two others mechanisms take place, namely **planner** and **executor**.
Our final parse tree will be use to build data result requested by user, but I
will not discuss here.

---

## Rebuilding an abstract tree

Recently, I wrote some dynamic SQL queries as part of a PL/pgSQL side-project.
This feature is quite common, it involves putting several pieces of expressions
together to write an SQL query whose parts (columns, tables, conditions) may vary.
Here is former prototype of the code: 

<!--
create table config (name text, value text);
insert into config values 
  ('column_name', 'name'),
  ('column_name', 'value'),
  ('table_name', 'config');
-->

```sql
DO $prototype$
DECLARE
  r record;
  v_columns text;
  v_tabname text;
  v_values text := $$ 1, 'test' $$;
BEGIN
  SELECT value INTO v_tabname
    FROM config WHERE name = 'table_name';

  SELECT string_agg(value, ',') INTO v_columns
    FROM config WHERE name = 'column_name';

  EXECUTE format(
    'INSERT INTO %s (%s) VALUES (%s);',
    v_tabname, v_columns, v_values
  );
END;
$prototype$;
```

Content of the `config` table is under the logic and could be critical when
construct a syntactically correct `INSERT` statement. In addition, in the more
than likely event that my needs are getting finer, this procedural code will
getting more complexe and finally may encounter trouble in maintenance and
scalability.

Talking to one of my [colleagues][13] about the obvious complications that were
growing in my prototype, he advices me to turn to a more advanced concept and make
my code more modular using a new abstraction level, aforementioned **AST** pattern.
This method is entirely based on a tree representation of a complex object that we
can manipulate and design easily.

[13]: https://github.com/dlax

In my case, it was about:

* Building a SQL statement as a parse tree;
* Deparsing back without lexical or syntactic error when needed

In few weeks after, a out-of-nowhere [solution][14] flashed in my Twitter timeline,
a pure PL/pgSQL extension called [postgres-ast-deparser][15]. Its main goals are
building abstract trees and deparsing back into SQL statements! After a few
discussions with its author Dan Lynch, I used a series of AST functions to
improve my procedural code.

[14]: https://twitter.com/fljdin/status/1538972129156337666
[15]: https://github.com/pyramation/postgres-ast-deparser

```sql
DO $prototype$
DECLARE
  v_relation jsonb;
  v_columns jsonb;
  v_values jsonb := to_jsonb(ARRAY[ARRAY[
    ast.a_const(v_val := ast.integer(1)),
    ast.a_const(v_val := ast.string('test'))
  ]]);
BEGIN
  SELECT ast_helpers.range_var(
      v_schemaname := 'public', 
      v_relname := value) INTO v_relation
    FROM config WHERE name = 'table_name';

  SELECT jsonb_agg(ast.res_target(
      v_name := value)) INTO v_columns
    FROM config WHERE name = 'column_name';

  EXECUTE deparser.expression(ast.insert_stmt(
    v_relation := v_relation,
    v_cols := v_columns,
    v_selectStmt := ast.select_stmt(
      v_valuesLists := v_values,
      v_op := 'SETOP_NONE'
    )
  )) FROM config WHERE name = 'table_name';
END;
$prototype$;
```

The extension offers a bunch of methods in the `ast` and `ast_helpers` schemas
to create tree nodes as JSONB structures. Nesting several calls let us have a
entire tree with the upper node `InsertStmt`, as defined by PostgreSQL
parser itself!

---

## Conclusion

By manipulating trees with JSONB, I realized how powerfull are projects like
`postgres-ast-deparser`. This extension relies on a other work called 
[libpg_query][16], provided by [pganalyze](https://pganalyze.com/) engineers, 
which use the internal parser outside of PostgreSQL!

[16]: https://github.com/pganalyze/libpg_query

Use-cases may be numerous, like syntax highlighting or validation, prettying 
query newlines ou serializing a statement to easily drop or modify internal
nodes, etc. A other parsing project wrote in Python, called `pglast`, suggests 
you in its [documentation][17] more examples, if by chance, this article has 
aroused your curiosity.

[17]: https://pglast.readthedocs.io/en/v3/usage.html