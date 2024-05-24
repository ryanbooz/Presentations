/*
 * Demo SQL from the talk:
 *   "Transforming data with the power of PostgreSQL and SQL"
 * 
 * Some of these samples require the tables and data from
 * the first 10 days of the Advent of Code to be available.
 * You can find the data and scripts for each day at
 * 
 * https://github.com/ryanbooz/advent-of-code-2023
 */

/*
 * Setup for initial Recursive query example
 */
CREATE TABLE files_on_disk (
	name TEXT,
	parent_folder TEXT,
	SIZE bigint
);

INSERT INTO files_on_disk VALUES
	('Folder_A',NULL,NULL),
	('Folder_A_1','Folder_A',NULL),
	('Folder_B','Folder_A',NULL),
	('Folder_A_2','Folder_A',NULL),
	('Folder_B_1','Folder_B',NULL),
	('File_A1.txt','Folder_A',1234),
	('File_A2.txt','Folder_A',6789),
	('File_B1.txt','Folder_B',4567);


SELECT regexp_split_to_table($$32T3K 765
T55J5 684
KK677 28
KTJJT 220
QQQJA 483$$,'\n') lines;

SELECT $$32T3K 765
T55J5 684
KK677 28
KTJJT 220
QQQJA 483$$;

/*
 * CTE Example
 * 
 * This was the CTE used for Day 3 of Advent of Code.
 * 
 * I chose this example to show during the demo that because
 * it allowed me to show both how a CTE works and how you can
 * select from each CTE as you go, building up a query.
 * 
 * Once you have the dec03 data imported, uncomment each SELECT
 * statement one at a time to see how the query progresses.
 */
select * from dec03;

-- Start by splitting the string apart appropriately.
with rucksack as (
	select id, 
		substring(contents,1,length(contents)/2) sack1, 
		substring(contents,length(contents)/2+1) sack2
	from dec03
)
--SELECT * FROM rucksack;
,
contents1 as (
	select id, string_to_table(sack1,null) as item from rucksack 
)
--SELECT * FROM contents1;
,
contents2 as (
	select id, string_to_table(sack2,null) as item from rucksack
)
select sum(position(item in'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')) total_priority
from (
	select * from contents1
	intersect
	select * from contents2
) y;




/*
 * Recursive queries
 * 
 * These are two more straight forward examples of recursive queries.
 * 
 * In the Advent of Code solutions, using recursive queries was necessary
 * to handle many of the puzzles because they required referenceing previous
 * data transformations. In SQL, a recursive query is the only way to do
 * that unless you write a function or stored procedure. That would be a 
 * fine option, but my original goal was to just use SQL directly.
 * 
 * The first example uses a very simple set of data (above) to show
 * two iterations of a filesystem listing to fine parent/child relationships.
 */
SELECT * FROM files_on_disk;

WITH recursive files AS (
	-- this is the static, non-recursive query that gets things started
	-- and fills the "working table" with the first set of data to JOIN 
	-- to in the recursive query after the UNION
	SELECT name, parent_folder, SIZE FROM files_on_disk
	WHERE parent_folder IS NULL
	UNION
	-- this is the recursive query. because it is the table on disk
	-- back to the output of the last iteration, we can iterate
	-- a set of data to find relationships and reach backward
	SELECT fid.name, fid.parent_folder AS parent_path, 
	    fid.SIZE FROM files_on_disk fid
		INNER JOIN files f ON fid.parent_folder = f.name
)
SELECT * FROM files;

SELECT fid.name, fid.parent_folder AS parent_path, 
	    fid.SIZE FROM files_on_disk fid
	   WHERE parent_folder = 'Folder_B';
/*
 * The same example as above, but now we're actually using data from the
 * previous iteration to build a "file path".
 */
WITH recursive files AS (
	SELECT name, COALESCE(parent_folder,'') parent_path, SIZE FROM files_on_disk
	WHERE parent_folder IS NULL
	UNION
	SELECT fid.name, f.parent_path || '\' || fid.parent_folder AS parent_path, 
	    fid.SIZE FROM files_on_disk fid
		INNER JOIN files f ON fid.parent_folder = f.name
)
SELECT * FROM files;

/*
 * One last example that requires no table data is the Fibonacci sequence.
 * 
 * In this example we set the static, non-recursive query with raw values rather
 * than selecting from a table, which is totally valid in SQL or a CTE. 
 * 
 * This also shows an example of needing to set an "end point" for the
 * recursion. Without the WHERE clause, this would run forever, or at least
 * until PostreSQL crashes. Always be aware of how your recursion is
 * written to ensure there is a stopping point.
 * 
 * The stopping point will come either when the working table (recursive query output)
 * is empty or the WHERE clause is met.
 */
-- Another example using the Fibonacci Sequence
WITH RECURSIVE fib_seq(level,pnum,cnum) AS
(
	SELECT 1 ,0::numeric, 1::numeric 
	UNION ALL
	SELECT fib_seq.LEVEL+1, 
		   fib_seq.cnum,
		   fib_seq.pnum+fib_seq.cnum 
	   FROM fib_seq
 	-- Stop at a certain level 
 	WHERE fib_seq.level <= 50
)
SELECT * FROM fib_seq;


/*
 * FILTER Clause
 * 
 * The FILTER clause can be added to many aggregate and window functions.
 * It acts as... well... filter for each incoming row before the function
 * can process the data. If the row matches the filter, the function includes
 * it. Otherwise, the row is disgarded and the next row is checked.
 * 
 * As I mentioned in the slides, FILTER is very useful for creating pivot-like
 * queries and for solving a problem like we had on day 1 of AoC.
 * 
 * From day 1 of AoC
 */
select * from dec01
order by id;

WITH inventory AS (
    SELECT
        nullif(calories, '')::bigint AS calories,
        count(*) FILTER (WHERE calories is null) OVER (ORDER BY id) AS elf,
        id
    FROM
        dec01
)
SELECT sum(calories) as c
	FROM inventory
	GROUP BY elf
	ORDER BY 1 desc;


/*
 * Converting textual data to usable
 * rows, arrays, or JSON objects
 * 
 * This is a really powerful topic and one of the best parts of using
 * PostgreSQL for ELT in my opinion. These are just a few examples,
 * primarily to show how existing functions can take raw data and easily
 * transform it into other useful forms for querying.
 * 
 * Using items functions like regexp_matches is really, really helpful
 * for pulling data apart that otherwise can't be easily manipulated.
 * 
 * There's so much more to explore than what is here, but there's only
 * so much time in a 45 minute talk. 🙂
 */
SELECT string_to_table('abcdegf',null); -- PostgreSQL 14+
SELECT UNNEST(string_to_array('abcdegf',null));

SELECT * FROM string_to_table('abcdegf',null); -- PostgreSQL 14+
SELECT * FROM string_to_array('abcdegf',null);

SELECT json_object_agg(KEY, value) FROM ( 
	SELECT * FROM json_each('{"a":1, "b":2,"c":{"c1":10,"c2":11}}')
) a;


-- Using regexp_match (first match) from Day 5 example
SELECT * FROM dec05;

SELECT id, 
   regexp_match(puzzle_input,
	'^move ([\d]+) from ([\d]+) to ([\d]+)') as t
 FROM dec05;

-- need a sub-select to get individual members
SELECT id, t[1], t[2], t[3] FROM (
	SELECT id, 
	   regexp_match(puzzle_input,
		'^move ([\d]+) from ([\d]+) to ([\d]+)') as t
	 FROM dec05
) a;


/*
 * CROSS JOIN LATERAL
 * 
 * Of all the things we've discussed so far, using the 
 * CROSS JOIN LATERAL functionality to process raw data row
 * by row is super powerful. Once you learn and understand how
 * the CROSS JOIN LATERAL works, there's so much interesting
 * processing that can be achieved.
 * 
 * Additionally, as you'll see in some of the later days of
 * the Advent of Code challenges, you can use a CROSS JOIN LATERAL
 * as a way of simplifying the rows that are returned to queries
 * higher up.
 * 
 */
-- for every row of the first set, iterate all rows
-- of the second set
SELECT * FROM 
	generate_series(1,5) a,
	generate_series(1,5) b;

-- Dec05 puzzle again, but this time the data that is
-- being returned is a set which can be referenced directly,
-- rather than with a subselect
select id,
	--	t,
		t[1]::int boxes,
		t[2]::int src,
		t[3]::int dest
	from dec05, 
	regexp_match(puzzle_input,
		'^move ([\d]+) from ([\d]+) to ([\d]+)') as t;

/*
 * Crazy fun with arrays and WORDLE!
 * 
 * Same principles as above, and by using cross joins, we can
 * rerences the output of each set to do additional work on it.
 */
-- The output of this CTE would be one row for each word guess
-- of a puzzle, three in the case of the example below.
WITH wordle_score AS (
	select * from 
	   regexp_matches($$Not as easy as you think
					#Wordle 511 3/6*
					🟨⬜🟨⬜⬜
					⬜🟨🟨🟨🟨
					🟩🟩🟩🟩🟩
				$$,'([🟩|🟧|🟨|🟦|⬛|⬜|]{5})','g') WITH ORDINALITY AS g(guess, guess_num)
)		
-- By doing a cross join lateral on the output of the CTE (one row per word guess)
-- we can then pass each row into another cross join to get a set of data for each
-- guess, this time pulling apart each leter of the word.
SELECT *
FROM wordle_score ws,
	regexp_matches(ws.guess[1],'([⬛|🟩|🟨|⬜]{1})','g') WITH ORDINALITY AS r(c1, letter)

	
/*
 * With ordinality
 * 
 * PostgreSQL is the only mainline DB that supports ORDINALITY for Set Returning Functions (SRF)
 * 
 * This allows a function to return an ordering value as part of the return set
 * so that a second pass with something like row_number() doesn't have to be used.
 * 
 * The other issue with row_number() is that the ordering value **could** change simply by
 * adding a different partition or ORDER BY clause. 
 * 
 * ORDINALITY retains the order of the items as they were provided as part of the result
 * set before any additional processing takes place.
 * 
 */
SELECT * FROM dec08;

-- normally, we would have to use something like row_number() to get the
-- order of values that came out of the function
SELECT id, 
	row_number() OVER(PARTITION BY id),
	tree
FROM (
	SELECT id,
		string_to_table(trees,null) tree
	FROM dec08
) t;

-- Straight forward using WITH ORDINALITY
SELECT t.o,
       d.id,
       t.tree::int
FROM dec08 AS d
	CROSS JOIN LATERAL string_to_table(trees, NULL) WITH ORDINALITY AS t (tree, o)
	
	

/*
 * WINDOW functions
 * 
 * Window functions are an art unto themselves. Once you understand how
 * they process query results and the way they can be used together with
 * respect to the current row, many possibilities open up to you.
 * 
 * There are a number of excellent tutorials online that dig more
 * deeply into window functions, but hopefully the slides and
 * one quick example start to give you an idea of how to change
 * some queries for more efficient processing.
 * 
 */
	
-- without a window function, this query does the same thing
-- but literally iterates the dataset one row and column at a time
-- which is resource intensive and slow.
with trees (x, y, tree) AS (
    SELECT t.o,
           d.id,
           t.tree::int
    FROM dec08 AS d
    CROSS JOIN string_to_table(trees, NULL) WITH ORDINALITY AS t (tree, o)
)
select sum(visible) from (
	select m.x, m.y, tree, 
		case when m.y = maxh.miny or m.y = maxh.maxy then 1
		when m.x = maxh.minx or m.x = maxh.maxx then 1 
		when tree > (select max(tree) from trees where x < m.x and y = m.y) then 1
		when tree > (select max(tree) from trees where x > m.x and y = m.y) then 1
		when tree > (select max(tree) from trees where y < m.y and x = m.x) then 1
		when tree > (select max(tree) from trees where y > m.y and x = m.x) then 1
		else 0 end visible
	from trees m
	CROSS JOIN
		(select min(x), max(x), min(y), max(y) FROM trees) AS maxh(minx, maxx, miny, maxy)
) j;


-- Using a window function over four different partitions achieves the
-- same result, but only requires processing the data four times, not
-- one for each item (rows and columns in this example)
with trees (x, y, tree) AS (
    SELECT t.o,
           d.id,
           t.tree::int
    FROM dec08 AS d
    CROSS JOIN string_to_table(trees, NULL) WITH ORDINALITY AS t (tree, o)
)
select count(*) from (
	select x, y, tree, 
			tree > COALESCE(MAX(tree) OVER from_north, -1) or
	        tree > COALESCE(MAX(tree) OVER from_east,  -1) or
	        tree > COALESCE(MAX(tree) OVER from_south, -1) or
	        tree > COALESCE(MAX(tree) OVER from_west,  -1) as visible
	FROM trees
	WINDOW from_north AS (PARTITION BY x ORDER BY y ASC  ROWS UNBOUNDED PRECEDING EXCLUDE CURRENT ROW),
	       from_east  AS (PARTITION BY y ORDER BY x DESC ROWS UNBOUNDED PRECEDING EXCLUDE CURRENT ROW),
	       from_south AS (PARTITION BY x ORDER BY y DESC ROWS UNBOUNDED PRECEDING EXCLUDE CURRENT ROW),
	       from_west  AS (PARTITION BY y ORDER BY x ASC  ROWS UNBOUNDED PRECEDING EXCLUDE CURRENT ROW)
	) j
where visible;
	

/*
 * Range types
 * 
 * As I often say in talks, I love some of the unique data types that PostgreSQL
 * has to offer. Array's are often my go-to for tasks, even when I should have 
 * thought of a better solution.
 * 
 * In many cases, range types can solve complex problems in an efficient
 * way, using all of the same comparison operators as array types, plus
 * many others!
 * 
 */
select * from dec04
order by id;

select id, tasks, SPLIT_PART(tasks,',',1), SPLIT_PART(tasks,',',2) from dec04; 

-- First, take the strings and get them into arrays
-- so that it's easy to use the comparison operators 
-- to help find the solution
with task_arrays as (
	select id, generate_series(elf1[1]::int,elf1[2]::int) t1, generate_series(elf2[1]::int,elf2[2]::int) t2 from (
		select id, STRING_TO_ARRAY(SPLIT_PART(tasks,',',1),'-') elf1, STRING_TO_ARRAY(SPLIT_PART(tasks,',',2),'-') elf2  from dec04
	) x
),
task_groups as (
	select id, array_agg(t1) FILTER (where t1 is not null) tl1, array_agg(t2) FILTER (where t2 is not null) tl2 from task_arrays
	group by id
)
select sum(overlap) from (
	select case 
		when tl1 @> tl2 then 1 
		when tl1 <@ tl2 then 1
		else 0 end overlap
	from task_groups
) a; 

-- Now with a little format magic, we can create some range types
-- with less SQL and do the same comparison. In reality, we'd actually
-- have even more operators to check for other range condidions.
with task_groups as (
	select id, elf1,elf2, 
		format($$[%s]$$,elf1)::int4range tl1, 
		format($$[%s]$$,elf2)::int4range tl2 
	from (
		select id, REPLACE (SPLIT_PART(tasks,',',1),'-',',') elf1, replace(SPLIT_PART(tasks,',',2),'-',',') elf2  from dec04
	) x
)
select sum(overlap) from (
	select case 
		when tl1 @> tl2 then 1 
		when tl1 <@ tl2 then 1
		else 0 end overlap
	from task_groups
) a; 


	
	
	