-- Step 1: Create the SearchTerms Table and NC Index
CREATE TABLE [ref].[SearchTerms] (
    [SearchTermId] INT      IDENTITY (1, 1) NOT NULL,
    [Trigram]      CHAR (3) NOT NULL,
    [FirstNameId]  INT      NOT NULL,
    CONSTRAINT [PKC_SearchTermId] PRIMARY KEY CLUSTERED ([SearchTermId] ASC)
);
GO

CREATE NONCLUSTERED INDEX [IX_Trigram_FirstNameId]
    ON [ref].[SearchTerms]([Trigram] ASC) WITH (DATA_COMPRESSION = ROW);
GO


-- Step 2: Create function to generate Trigrams from text
CREATE FUNCTION ref.GenerateTrigrams (@string varchar(255))
RETURNS table
WITH SCHEMABINDING
AS RETURN
    WITH
        N16 AS 
        (
            SELECT v
            FROM 
            (
                VALUES 
                    (0),(0),(0),(0),(0),(0),(0),(0),
                    (0),(0),(0),(0),(0),(0),(0),(0)
            ) AS V (v)),
        -- Numbers table (256)
        Nums AS 
        (
            SELECT n = ROW_NUMBER() OVER (ORDER BY A.v)
            FROM N16 AS A 
            CROSS JOIN N16 AS B
        ),
        Trigrams AS
        (
            -- Every 3-character substring
            SELECT TOP (CASE WHEN LEN(@string) > 2 THEN LEN(@string) - 2 ELSE 0 END)
                trigram = SUBSTRING(@string, N.n, 3)
            FROM Nums AS N
            ORDER BY N.n
        )
    -- Remove duplicates and ensure all three characters are alphanumeric
    SELECT DISTINCT 
        T.trigram
    FROM Trigrams AS T
    --WHERE
    --    -- Binary collation comparison so ranges work as expected
    --    T.trigram COLLATE Latin1_General_BIN2 NOT LIKE '%[^A-Z0-9a-z ]%';
GO

-- Step 3: Create SPROC that creates Trigrams from BabbyName Data
CREATE PROC [ref].[GenerateSearchTerms]
AS
BEGIN

	INSERT ref.SearchTerms WITH (TABLOCKX)
		 (Trigram, FirstNameId)
	SELECT
		GT.trigram,
		FN.FirstNameId
	FROM ref.FirstName AS FN
	CROSS APPLY ref.GenerateTrigrams(FN.FirstName) AS GT;

END
GO

-- Step 4: Create Post Deploy script to populate SearchTerms if necessary
/*
  Check to see if the SearchTerms table has data in it. If not, 
  call the SPROC that will generate Trigram search terms for all 
  baby names
*/
IF NOT EXISTS (SELECT 1 FROM ref.SearchTerms WHERE Trigram IS NOT NULL)
BEGIN
	EXEC ref.GenerateSearchTerms
END
GO

-- Step 5: Do we have search terms after deployment?
SELECT COUNT(*) FROM ref.SearchTerms
GO

-- Step 6: Create Indexed view to help weight trigram value
-- Selectivity of each trigram (performance optimization)
CREATE VIEW ref.FirstNameCounts
WITH SCHEMABINDING
AS
	SELECT ST.Trigram, cnt = COUNT_BIG(*)
	FROM ref.SearchTerms AS ST
	GROUP BY ST.Trigram;
GO

CREATE UNIQUE CLUSTERED INDEX [CUX_FirstNameCounts_Trigram]
    ON [ref].[FirstNameCounts]([Trigram] ASC);


GO


-- Step 7: Get the top three trigrams that have the highest count of usage - the most popular
CREATE FUNCTION ref.GetBestTrigrams (@string varchar(255))
RETURNS table
WITH SCHEMABINDING AS
RETURN
    SELECT
        -- Pivot
        trigram1 = MAX(CASE WHEN BT.rn = 1 THEN BT.trigram END),
        trigram2 = MAX(CASE WHEN BT.rn = 2 THEN BT.trigram END),
        trigram3 = MAX(CASE WHEN BT.rn = 3 THEN BT.trigram END)
    FROM 
    (
        -- Generate trigrams for the search string
        -- and choose the most selective three
        SELECT TOP (3)
            rn = ROW_NUMBER() OVER (
                ORDER BY FNC.cnt ASC),
            GT.trigram
        FROM ref.GenerateTrigrams(@string) AS GT
        JOIN ref.FirstNameCounts AS FNC
            WITH (NOEXPAND)
            ON FNC.Trigram = GT.trigram
        ORDER BY
            FNC.cnt ASC
    ) AS BT;
GO


-- Step 8: Create Function to get IDs of the trigrams that match the top three
CREATE FUNCTION ref.GetTrigramMatchIDs
(
    @Trigram1 char(3),
    @Trigram2 char(3),
    @Trigram3 char(3)
)
RETURNS @IDs table (id integer PRIMARY KEY)
WITH SCHEMABINDING AS
BEGIN
    IF  @Trigram1 IS NOT NULL
    BEGIN
        IF @Trigram2 IS NOT NULL
        BEGIN
            IF @Trigram3 IS NOT NULL
            BEGIN
                -- 3 Trigrams available
                INSERT @IDs (id)
                SELECT ET1.FirstNameId
                FROM ref.SearchTerms AS ET1 
                WHERE ET1.Trigram = @Trigram1
                INTERSECT
                SELECT ET2.FirstNameId
                FROM ref.SearchTerms AS ET2
                WHERE ET2.Trigram = @Trigram2
                INTERSECT
                SELECT ET3.FirstNameId
                FROM ref.SearchTerms AS ET3
                WHERE ET3.Trigram = @Trigram3
                OPTION (MERGE JOIN);
            END;
            ELSE
            BEGIN
                -- 2 Trigrams available
                INSERT @IDs (id)
                SELECT ET1.FirstNameId
                FROM ref.SearchTerms AS ET1 
                WHERE ET1.Trigram = @Trigram1
                INTERSECT
                SELECT ET2.FirstNameId
                FROM ref.SearchTerms AS ET2
                WHERE ET2.Trigram = @Trigram2
                OPTION (MERGE JOIN);
            END;
        END;
        ELSE
        BEGIN
            -- 1 Trigram available
            INSERT @IDs (id)
            SELECT ET1.FirstNameId
            FROM ref.SearchTerms AS ET1 
            WHERE ET1.Trigram = @Trigram1;
        END;
    END;
 
    RETURN;
END;
GO


-- Step 9: Finally, return the FirstNames that match the top three trigrams
CREATE FUNCTION ref.FirstNameSearch
(
    @Search varchar(255)
)
RETURNS table
WITH SCHEMABINDING
AS
RETURN
    SELECT
        Result.FirstName, Result.FirstNameId
    FROM ref.GetBestTrigrams(@Search) AS GBT
    CROSS APPLY
    (
        -- Trigram search
        SELECT
            FN.FirstNameId,
            FN.FirstName
        FROM ref.GetTrigramMatchIDs
            (GBT.trigram1, GBT.trigram2, GBT.trigram3) AS MID
        JOIN ref.FirstName AS FN
            ON FN.FirstNameId = MID.id
        WHERE
            -- At least one trigram found 
            GBT.trigram1 IS NOT NULL
            --AND FN.FirstName LIKE @Search
 
) AS Result;

