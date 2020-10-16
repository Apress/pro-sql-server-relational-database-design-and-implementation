Stupid Mathematic Tricks
/*
I want to give you a final, (hopefully) entertaining, and esoteric usage of the sequence table to get your mind working on the
 possibilities. One of my favorite episodes of Futurama is an episode called “Lesser of Two Evils.” In this episode, Bender 
 and the Bender look-alike named Flexo (they are both Bender units… Did someone call for a nerd?) start talking and have the 
 following exchange:
Bender: Hey, brobot, what’s your serial number?
Flexo: 3370318.
Bender: No way! Mine’s 2716057!
Fry (a human): I don’t get it.
Bender: We’re both expressible as the sum of two cubes!
So, I figured, the sum of two cubes would be an interesting and pretty easy abstract utilization of the numbers table. “Taxicab”
 numbers are also mentioned on the ScienceNews.org web site,  where the goal is to discover the smallest value that can be 
 expressed as the sum of three cubes in N different ways.?They are called taxicab numbers because of an old (and pretty darn nerdy)
  story in which one mathematician remarked to another mathematician that the number 1729 on a taxicab was “dull,” to which the
   other one remarked that it was very interesting, because it was the smallest number that could be expressed as the sum of two 
   cubes. (You can judge your own nerdiness by whether you think: A. This is stupid; B. This is cool; or C. You have done it yourself.)

How hard is the query? It turns out that once you have a sequence table with numbers from 1 to 100,000 or so, you can calculate that 
Taxicab(2) = 1729 very easily (and all of the other numbers that are the sum of two cubes too) and the sum of two cubes in three 
different ways also pretty easily, It took three seconds on my laptop, and that value is 87539319.
But, instead of calculating the value of each integer cubed (power(i,3)) for each iteration, you can add a computed column to the 
table, this time as a bigint to give the later calculations room to store the very large intermediate values when you start to 
multiply the two cube values together. You can do something like the following:
*/
USE WideWorldImporters;
GO
ALTER TABLE Tools.Number
  ADD Ipower3 AS CAST( POWER(CAST(I AS bigint),3) AS bigint) PERSISTED;
  --Note that I had to cast I as bigint first to let the power function
  --return a bigint

--Now, here is the code:

DECLARE @level int = 2; --sum of two cubes in @level ways
;WITH cubes AS
(SELECT Ipower3
FROM   Tools.Number
WHERE  I >= 1 AND I < 500) --<<<Vary for performance, and for cheating reasons,
                           --<<<max needed value

SELECT c1.Ipower3 + c2.Ipower3 AS [sum of 2 cubes in @level Ways]
FROM   cubes AS c1
         CROSS JOIN cubes AS c2
WHERE c1.Ipower3 <= c2.Ipower3 --this gets rid of the "duplicate" value pairs

GROUP BY (c1.Ipower3 + c2.Ipower3)
HAVING count(*) = @level
ORDER BY [sum of 2 cubes in @level Ways];

/*
This will return 559 rows in just a second or two (and the query includes a sort of the output!) The first row is 1729, which 
is the smallest number that is the sum of two cubes in two different ways. OK, breaking this down the cube’s CTE, the code is pretty simple.

(SELECT Ipower3
FROM    Tools.Number
WHERE   I >= 1 AND I < 500) 

This limits the values to a table of cubes, but only the first 499. The next part of the query is a bit more interesting. I sum the 
two cube values, which I get from cross-joining the CTE to itself.

SELECT c1.Ipower3 + c2.Ipower3 AS [sum of 2 cubes in @level Ways]
FROM   cubes AS c1
           CROSS JOIN cubes AS c2
WHERE  c1.Ipower3 <= c2.Ipower3 --this gets rid of the "duplicate" value pairs
The WHERE condition of c1.i3 <= c2.i3 gets rid of the “duplicate” value pairs since c1 and c2 have the same values, so without this, 
for 1729 you would get the following:

c1.i3                c2.i3
-------------------- ----------------------
1                    1728
729                  1000
1000                 729
1728                 1

These pairs are the same, technically, just in reverses. I don’t eliminate equality to allow for the case where both numbers are equal, 
because they won’t be doubled up in this set and if the two cubes were of the same number, it would still be interesting if it were the 
same as a different sum of two cubes. With the following values:
c1.i3                c2.i3
-------------------- ----------------------
1                    1728
729                  1000
Now you can see that 1729 is the sum of two cubes in two different ways. So, lastly, the question of performance must come up. 
Reading the articles, it is clear that this is not a terribly easy problem to solve as the values get really large. Values for 
the sum of three cubes are fairly simple. Leaving the sequence values bounded at 500.

*/

DECLARE @level int = 3; --sum of two cubes in @level ways
;WITH cubes AS
(SELECT Ipower3
FROM   Tools.Number
WHERE  I >= 1 AND I < 500) --<<< Vary for performance, and for cheating reasons,
                           --<<< max needed value

SELECT c1.Ipower3 + c2.Ipower3 AS [sum of 2 cubes in @level Ways]
FROM   cubes AS c1
         CROSS JOIN cubes AS c2
WHERE c1.Ipower3 < c2.Ipower3
GROUP BY (c1.Ipower3 + c2.Ipower3)
HAVING count(*) = @level
ORDER BY [sum of 2 cubes in @level Ways];

/*
This returns in around less than a second:

sum of 2 cubes in @level Ways
-----------------------------
87539319
119824488

Four, however, was a “bit” more challenging. Knowing the answer from the article, I knew I could set a boundary for my numbers using 20000 and get the answer.
*/

DECLARE @level int = 4 --sum of two cubes in @level ways

;WITH cubes AS
(SELECT Ipower3
FROM   Tools.Number
WHERE  I >= 1 and I < 20000) --<<<Vary for performance, and for cheating reasons,
                           --<<<max needed value

SELECT c1.Ipower3 + c2.Ipower3 AS [sum of 2 cubes in @level Ways]
FROM   cubes AS c1
         CROSS JOIN cubes AS c2
WHERE c1.Ipower3 < c2.Ipower3
GROUP BY (c1.Ipower3 + c2.Ipower3)
HAVING count(*) = @level
ORDER BY [sum of 2 cubes in @level Ways];

/*
 Using this “cheat” of knowing how to tweak the number you need to on my laptop’s VM, I was able to calculate that the minimum 
 value of taxicab(4) was 6963472309248 (yes, it found only the one) in just 2 hours and 42 seconds on the same VM and laptop 
 mentioned earlier. Clearly, the main value of T-SQL isn’t in tricks like this but that using a sequence table can give you the 
 immediate jumping-off point to solve some problems that initially seem difficult.

Caution	Be careful where you try this code for very large values of @level. A primary limiting factor is tempdb space and you don’t
 want to blow up the tempdb on your production server only to have to explain this query to your manager. Trust me.
*/
