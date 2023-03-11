CREATE TABLE film (
	film_id int PRIMARY KEY,
	title TEXT NOT NULL,
	film_type TEXT[] NULL	
);

-- We can insert as literal string values
INSERT INTO film 
VALUES (1,'Power to Postgres', '{documentary,thriller,action}');

-- or as an array constructor
INSERT INTO film 
VALUES (2,'PostgreSQL 2: The SQL', ARRAY['documentary','suspense','action']);

SELECT * FROM film;

-- select the first element of the array
-- remember that PostgreSQL is one-based, not zero
SELECT film_type[1] FROM film;

-- However, referencing an element that doesn't exist
-- will not throw an error
SELECT film_type[0] FROM film;

/*
 * Pivot with unnest and array_agg
 */
-- pivot the array into rows
SELECT unnest(film_type) FROM film WHERE film_id=1;
SELECT title, unnest(film_type) FROM film WHERE film_id=1;

-- create an array aggregation out a selection
SELECT array_agg(title) FROM film;
-- it's an aggregation that supports ORDER BY
SELECT array_agg(title ORDER BY title) FROM film;
-- and FILTER
SELECT array_agg(title ORDER BY title) 
	FILTER (WHERE title LIKE '%:%') FROM film;

/*
 * Slicing
 */
-- we can refer to them by slices
SELECT title, film_type[1:2] FROM film;
SELECT title, film_type[1:1] FROM film;

SELECT title, film_type[2:] FROM film;
-- and use dynamic values with other array functions
SELECT title, film_type[:array_length(film_type,1)-1] FROM film;

-- arrays can be updated in whole
SELECT film_type FROM film WHERE film_id=2;

/*
 * Updating
 */
UPDATE film SET film_type = '{documentary,thriller,action}'
WHERE film_id=2;

SELECT film_type FROM film WHERE film_id=2;

-- or in part
UPDATE film SET film_type[2] = 'suspense'
WHERE film_id=2;

/*
 * Multi-dimensional
 */
-- Postgres supports multi-dimensional arrays
-- this is a 3x3 array
SELECT ARRAY[[1,2,3],[4,5,6],[7,8,9]];

-- But arrays must be the same length
SELECT ARRAY[[1,2,3],[4,5,6],[7,8,9,10]];

/*
 * Appending
 */
-- We can append arrays together of the same type
-- to create new arrays
SELECT array_append(film_type,'SCaLE20x') FROM film;
SELECT array_append(film_type,1234::text) FROM film;

SELECT film_type || '{SCaLE20x}' FROM film;

-- But they need to clearly be arrays (literal)
SELECT film_type || 'SCaLE20x' FROM film;

/*
 * Searching arrays
 */
-- Searching arrays in total
SELECT * FROM film WHERE 'documentary' = any(film_type);
-- or searching a specific element
SELECT * FROM film WHERE film_type[1] = 'documentary';

-- searching for any value in the array that matches
SELECT * FROM film WHERE 'suspense' = any(film_type);
-- && is known as the "overlap" operator
SELECT * FROM film WHERE film_type && '{suspense}';

-- and finally there is 'contains'. The array on the 
-- side of the @ symbol is used as the template and 
-- Postgres "probes" with the other side to see if 
-- to see if it's fully contained in the template
SELECT * FROM film WHERE film_type @> '{suspense}';

-- this returns nothing because 'film_type' has more
-- values that are not contained in the template
SELECT * FROM film WHERE film_type <@ '{suspense}';

-- but this does work, regardless of the order
SELECT * FROM film WHERE film_type <@ '{suspense,documentary,action}';

/*
 * Indexing
 */
-- Arrays can be indexed with GIN which makes it possible
-- to efficiently search for values within the array
CREATE INDEX idx_film_type ON film USING GIN (film_type);

-- Because this table is so small (2 rows), we have to 
-- suggest to Postgres NOT to just scann all the rows
SET enable_seqscan=OFF;

EXPLAIN analyze
SELECT * FROM film WHERE film_type @> '{suspense}';

SET enable_seqscan=ON;


/*
 * Slides....
 */




/*
 * Pattern matching
 */
-- essentially a "split to array"
SELECT string_to_array(title,' ') FROM film;
-- But it returns the string in whole if no match is found
SELECT string_to_array(title,':') FROM film;
-- I also can't refer to the elements directly
SELECT string_to_array(title,':')[1] FROM film;

-- Instead it needs to be the result of a set (in the FROM)
-- Again notice that the first one returns the entire string
SELECT p[1] FROM film 
	CROSS JOIN LATERAL string_to_array(title,':') AS p;

-- you can replace CROSS JOIN LATERAL with a comma shorthand
SELECT p[1] FROM film, string_to_array(title,':') AS p;


-- more power than 'string_to_array' with regex capabilities
SELECT regexp_split_to_array(title,'\s+') FROM film; 

-- more advanced splitting and pattern matching using regexp
-- with capturing groups 
SELECT regexp_match(title,'(.*):') FROM film;

-- only return the element from the title where
-- it started with text and contained a colon
SELECT p FROM film, regexp_match(title,'(.*):') AS p WHERE p IS NOT null;

-- and finally, we can use WITH ORDINALITY with the 
-- output of any SRF
SELECT title, ft.* FROM film, 
	unnest(film_type) WITH ORDINALITY AS ft(film_type,array_order);

-- first split the word and then unnest that
-- array for word order in this example
SELECT ft.* FROM film, 
	regexp_split_to_array(title,' ') WITH ORDINALITY ft(word,o);

SELECT ft.* FROM film, 
	unnest(regexp_split_to_array(title,' ')) WITH ORDINALITY ft(word,o);


/*
 * Now some fun with WORDLE emoji! 🙂
 */
-- First, a quick explainer of the $$ notation
SELECT $$Not as easy as you think
			#Wordle 511 3/6*
			🟨⬜🟨⬜⬜
			⬜🟨🟨🟨🟨
			🟩🟩🟩🟩🟩
		$$;

/*
 * Crazy fun with arrays and WORDLE!
 */
select * from regexp_matches($$Not as easy as you think
							#Wordle 511 3/6*
							🟨⬜🟨⬜⬜
							⬜🟨🟨🟨🟨
							🟩🟩🟩🟩🟩
						$$,'([🟩|🟧|🟨|🟦|⬛|⬜|]{5})','g') WITH ORDINALITY AS g(guess, guess_num);



WITH wordle_score AS (
	select * from regexp_matches($$Not as easy as you think
							#Wordle 511 3/6*
							🟨⬜🟨⬜⬜
							⬜🟨🟨🟨🟨
							🟩🟩🟩🟩🟩
						$$,'([🟩|🟧|🟨|🟦|⬛|⬜|]{5})','g') WITH ORDINALITY AS g(guess, guess_num)
)					
SELECT * FROM wordle_score;


-- Break it apart even further to get each separate letter
WITH wordle_score AS (
	select * from regexp_matches($$Not as easy as you think
							#Wordle 511 3/6*
							🟨⬜🟨⬜⬜
							⬜🟨🟨🟨🟨
							🟩🟩🟩🟩🟩
						$$,'([🟩|🟧|🟨|🟦|⬛|⬜|]{5})','g') WITH ORDINALITY AS g(guess, guess_num)
)					
SELECT *
FROM wordle_score ws,
	regexp_matches(ws.guess[1],'([⬛|🟩|🟨|⬜]{1})','g') WITH ORDINALITY AS r(c1, letter)

	
	
-- Now we can aggregate those individual letters
-- to see how many letters were right/wrong for each guess
WITH wordle_score AS (
	select * from regexp_matches($$Not as easy as you think
							#Wordle 511 3/6*
							🟨⬜🟨⬜⬜
							⬜🟨🟨🟨🟨
							🟩🟩🟩🟩🟩
						$$,'([🟩|🟧|🟨|🟦|⬛|⬜|]{5})','g') WITH ORDINALITY AS g(guess, guess_num)
)					
SELECT 
	guess_num,
	count(*) FILTER (WHERE c1[1]='🟩') AS c_correct,
	count(*) FILTER (WHERE c1[1]='🟨') AS c_partial,
	count(*) FILTER (WHERE c1[1] IN ('⬛','⬜')) AS c_incorrect
FROM wordle_score ws,
	regexp_matches(ws.guess[1],'([⬛|🟩|🟨|⬜]{1})','g') WITH ORDINALITY AS r(c1, letter)
GROUP BY 1;



/*
 * Inserting with arrays
 */
INSERT INTO film (film_id, title)  
	SELECT * FROM UNNEST('{3,4}'::int[],
				  '{Postgres 95: The beginning,Postgres 6: A new beginning}'::TEXT[]);				

SELECT film_id, title FROM film;