RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO

USE [BabbyNames-Local]
GO

/*
  After creating the first function, make sure it
  generates Trigrams
*/
SELECT * FROM ref.generateTrigrams('Vivienne')

/*
  Check to see if any search terms exist
*/
SELECT TOP 10 * FROM ref.SearchTerms

/*
  Check that the View works
*/
SELECT TOP 10 * FROM ref.FirstNameCounts

/*
  With all Functions created, can I search for a name and get back ID matches?
*/
SELECT * FROM ref.FirstNameSearch('Lia') order by FirstName

/*
	Now let's play with some ways of getting the data I want
*/
SELECT TOP 10 FNS.FirstName, FNBY.Gender, SUM(FNBY.NameCount) TotalNameCount FROM ref.FirstNameSearch('Malachi') AS FNS
INNER JOIN agg.FirstNameByYear FNBY ON FNS.FirstNameId = FNBY.FirstNameId
GROUP BY FNS.FirstName, FNBY.Gender
ORDER BY TotalNameCount DESC




/*
  Since I'm a child of the 80s...
*/
SELECT TOP 10 FNS.FirstName, FNBY.Gender, SUM(FNBY.NameCount) TotalNameCount FROM ref.FirstNameSearch('Audrey') AS FNS
INNER JOIN agg.FirstNameByYear FNBY ON FNS.FirstNameId = FNBY.FirstNameId
WHERE FNBY.ReportYear >=1980 AND fnby.reportyear < 1990
GROUP BY FNS.FirstName, FNBY.Gender
ORDER BY TotalNameCount DESC

GO
/*
  That's not bad, but we should make a SPROC to iterate variables more easily
  ... and be better stewards of our plan cache... right?
*/
CREATE PROC [ref].[FindBabyNames]
	@topN int = 10,
	@name varchar(20) = 'Ryan',
	@startYear int = 1900,
	@numberOfYears int = 10
AS
BEGIN

	DECLARE @endYear INT = @startYear+@numberOfYears;

	SELECT TOP(@topN) FNS.FirstName, A.Gender, SUM(A.totalCount) TotalNameCount FROM ref.FirstNameSearch(@name) AS FNS
	CROSS APPLY (
		-- This TOP (max INT) tricks the planner into doing this search 
		-- like I want it to since I know my data
		SELECT TOP(2147483647) B.Gender, B.totalCount FROM 
		( 
			SELECT FNBY.Gender, FNBY.NameCount totalCount FROM agg.FirstNameByYear FNBY
			WHERE
				FNBY.firstNameID = FNS.firstNameId AND 
				FNBY.ReportYear >=@startYear AND fnby.reportyear < @endYear
		) B
	) A
	GROUP BY FNS.FirstName, A.Gender
	ORDER BY TotalNameCount DESC

END

/*
	Let's start searching!
*/
EXEC ref.FindBabyNames @topN = 20,         -- int
                       @name = 'Josiah',     -- varchar(20)
                       @startYear = 1920,  -- int
                       @numberOfYears = 100 -- int


/*
	Hmmmm... that feels pretty slow doesn't it. What kind of work
	is actually going on for this?
*/

CREATE NONCLUSTERED INDEX IX_FirstNameByYear_FirstNameId_ReportYear
ON [agg].[FirstNameByYear] ([FirstNameId],[ReportYear])



EXEC ref.FindBabyNames @topN = 10,         -- int
                       @name = 'John',     -- varchar(20)
                       @startYear = 1970,  -- int
                       @numberOfYears = 30 -- int


