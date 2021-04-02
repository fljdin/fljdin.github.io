---
title: "Partition by Hash"
categories: []
tags: []
date: 2099-03-16
draft: true
---

<!--
* démo partition by hash sur un UUID
* remonter sur la règle de hash dans le code de PG 
-->

```sql
create extension pgcrypto;
CREATE TABLE t2(c1 uuid, c2 text) PARTITION BY HASH (c1);
CREATE TABLE t3_1 PARTITION OF t3 FOR VALUES WITH (modulus 3, remainder 0);
CREATE TABLE t3_2 PARTITION OF t3 FOR VALUES WITH (modulus 3, remainder 1);
CREATE TABLE t3_3 PARTITION OF t3 FOR VALUES WITH (modulus 3, remainder 2);
INSERT INTO t3 SELECT gen_random_uuid(), g FROM generate_series(100, 10000) g;
```

```
                                   Table "public.t3"
 Column | Type | Collation | Nullable | Default | Storage  | Stats target | Description 
--------+------+-----------+----------+---------+----------+--------------+-------------
 c1     | uuid |           | not null |         | plain    |              | 
 c2     | text |           |          |         | extended |              | 
Partition key: HASH (c1)
Indexes:
    "t3_pk" PRIMARY KEY, btree (c1)
Partitions: t3_1 FOR VALUES WITH (modulus 3, remainder 0),
            t3_2 FOR VALUES WITH (modulus 3, remainder 1),
            t3_3 FOR VALUES WITH (modulus 3, remainder 2)
```

```
florent=# EXPLAIN (analyze,buffers) SELECT * FROM t3 WHERE c1 in ('fbc09d52-c6d5-45e0-8b11-88c5108106ae', 'b7f7f6f2-b1c0-48b9-95dc-2692cd8651f5');
                                                          QUERY PLAN                                                          
------------------------------------------------------------------------------------------------------------------------------
 Append  (cost=8.58..29.56 rows=4 width=20) (actual time=0.073..0.111 rows=2 loops=1)
   Buffers: shared hit=10
   ->  Bitmap Heap Scan on t3_1  (cost=8.58..14.75 rows=2 width=20) (actual time=0.071..0.072 rows=1 loops=1)
         Recheck Cond: (c1 = ANY ('{fbc09d52-c6d5-45e0-8b11-88c5108106ae,b7f7f6f2-b1c0-48b9-95dc-2692cd8651f5}'::uuid[]))
         Heap Blocks: exact=1
         Buffers: shared hit=5
         ->  Bitmap Index Scan on t3_1_pkey  (cost=0.00..8.58 rows=2 width=0) (actual time=0.037..0.038 rows=1 loops=1)
               Index Cond: (c1 = ANY ('{fbc09d52-c6d5-45e0-8b11-88c5108106ae,b7f7f6f2-b1c0-48b9-95dc-2692cd8651f5}'::uuid[]))
               Buffers: shared hit=4
   ->  Bitmap Heap Scan on t3_2  (cost=8.58..14.79 rows=2 width=20) (actual time=0.035..0.036 rows=1 loops=1)
         Recheck Cond: (c1 = ANY ('{fbc09d52-c6d5-45e0-8b11-88c5108106ae,b7f7f6f2-b1c0-48b9-95dc-2692cd8651f5}'::uuid[]))
         Heap Blocks: exact=1
         Buffers: shared hit=5
         ->  Bitmap Index Scan on t3_2_pkey  (cost=0.00..8.58 rows=2 width=0) (actual time=0.032..0.033 rows=1 loops=1)
               Index Cond: (c1 = ANY ('{fbc09d52-c6d5-45e0-8b11-88c5108106ae,b7f7f6f2-b1c0-48b9-95dc-2692cd8651f5}'::uuid[]))
               Buffers: shared hit=4
 Planning Time: 1.684 ms
 Execution Time: 0.271 ms
(18 rows)
```