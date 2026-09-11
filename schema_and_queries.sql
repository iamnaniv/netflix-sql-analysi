-- ================================================================
-- Netflix Titles: SQL Analysis (Week 3)
-- Schema + 10 analytical queries using JOINs, aggregation, GROUP BY,
-- HAVING, and subqueries (including a window-function subquery).
-- Written for SQLite; minor syntax tweaks noted for Postgres/MySQL.
-- ================================================================

-- ---------- Schema ----------
CREATE TABLE titles (
    show_id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    director TEXT,
    release_year INTEGER,
    rating TEXT,
    date_added TEXT,
    year_added INTEGER,
    month_added INTEGER,
    duration_minutes REAL,
    duration_seasons REAL
);

CREATE TABLE title_countries (
    show_id TEXT NOT NULL,
    country TEXT NOT NULL,
    FOREIGN KEY (show_id) REFERENCES titles(show_id)
);

CREATE TABLE title_genres (
    show_id TEXT NOT NULL,
    genre TEXT NOT NULL,
    FOREIGN KEY (show_id) REFERENCES titles(show_id)
);
-- title_countries and title_genres are junction tables: the source data stores
-- multiple comma-separated countries/genres per title, so these were normalized
-- out into one row per (show_id, country) and (show_id, genre) pair. This is what
-- makes real JOINs possible instead of everything living in one flat table.

-- Q1. How many titles are Movies vs. TV Shows?
SELECT type, COUNT(*) AS title_count
FROM titles
GROUP BY type
ORDER BY title_count DESC;

-- Q2. What are the top 10 countries by number of titles?
SELECT tc.country, COUNT(*) AS title_count
FROM title_countries tc
JOIN titles t ON t.show_id = tc.show_id
WHERE tc.country != 'Unknown'
GROUP BY tc.country
ORDER BY title_count DESC
LIMIT 10;

-- Q3. What are the top 10 genres by number of titles?
SELECT tg.genre, COUNT(*) AS title_count
FROM title_genres tg
JOIN titles t ON t.show_id = tg.show_id
GROUP BY tg.genre
ORDER BY title_count DESC
LIMIT 10;

-- Q4. What is the average movie duration by decade of release?
SELECT (release_year / 10) * 10 AS decade,
       ROUND(AVG(duration_minutes), 1) AS avg_duration_minutes,
       COUNT(*) AS movie_count
FROM titles
WHERE type = 'Movie'
GROUP BY decade
ORDER BY decade;

-- Q5. How many titles were added to Netflix each year, split by type?
SELECT year_added, type, COUNT(*) AS titles_added
FROM titles
WHERE year_added IS NOT NULL
GROUP BY year_added, type
ORDER BY year_added, type;

-- Q6. Who are the top 10 directors by number of titles (excluding Unknown)?
SELECT director, COUNT(*) AS title_count
FROM titles
WHERE director != 'Unknown'
GROUP BY director
ORDER BY title_count DESC
LIMIT 10;

-- Q7. Which countries have more TV shows than movies in the catalog?
SELECT tc.country,
       SUM(CASE WHEN t.type = 'Movie' THEN 1 ELSE 0 END) AS movie_count,
       SUM(CASE WHEN t.type = 'TV Show' THEN 1 ELSE 0 END) AS tv_show_count
FROM title_countries tc
JOIN titles t ON t.show_id = tc.show_id
WHERE tc.country != 'Unknown'
GROUP BY tc.country
HAVING tv_show_count > movie_count
ORDER BY tv_show_count DESC;

-- Q8. Which movies run longer than the overall average movie duration?
SELECT title, duration_minutes
FROM titles
WHERE type = 'Movie'
  AND duration_minutes > (
      SELECT AVG(duration_minutes) FROM titles WHERE type = 'Movie'
  )
ORDER BY duration_minutes DESC;

-- Q9. For each of the top 5 countries by title count, what is their single most common genre?
WITH top_countries AS (
    SELECT tc.country, COUNT(*) AS title_count
    FROM title_countries tc
    JOIN titles t ON t.show_id = tc.show_id
    WHERE tc.country != 'Unknown'
    GROUP BY tc.country
    ORDER BY title_count DESC
    LIMIT 5
),
country_genre_counts AS (
    SELECT tc.country, tg.genre, COUNT(*) AS genre_count,
           RANK() OVER (PARTITION BY tc.country ORDER BY COUNT(*) DESC) AS genre_rank
    FROM title_countries tc
    JOIN title_genres tg ON tg.show_id = tc.show_id
    WHERE tc.country IN (SELECT country FROM top_countries)
    GROUP BY tc.country, tg.genre
)
SELECT country, genre, genre_count
FROM country_genre_counts
WHERE genre_rank = 1
ORDER BY genre_count DESC;

-- Q10. Which directors (excluding Unknown) have worked across more than 2 different genres?
SELECT t.director, COUNT(DISTINCT tg.genre) AS distinct_genres
FROM titles t
JOIN title_genres tg ON tg.show_id = t.show_id
WHERE t.director != 'Unknown'
GROUP BY t.director
HAVING distinct_genres > 2
ORDER BY distinct_genres DESC;
