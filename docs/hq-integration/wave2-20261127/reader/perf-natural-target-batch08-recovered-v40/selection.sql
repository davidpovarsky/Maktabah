SELECT b.id,b.title,b.totalLines,b.isBaseBook
FROM book b WHERE b.isBaseBook=1 AND (b.totalLines BETWEEN 1 AND 99 OR b.totalLines BETWEEN 10001 AND 50000)
AND b.id > 0 AND b.id NOT IN (103,28,3152)
AND EXISTS (SELECT 1 FROM tocEntry t WHERE t.bookId=b.id)
ORDER BY b.id LIMIT 40
