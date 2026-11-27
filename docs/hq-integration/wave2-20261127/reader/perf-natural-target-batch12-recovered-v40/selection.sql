SELECT b.id,b.title,b.totalLines,b.isBaseBook
FROM book b WHERE b.isBaseBook=0 AND b.totalLines BETWEEN 100 AND 10000
AND b.id > 539 AND b.id NOT IN (103,28,3152)
AND EXISTS (SELECT 1 FROM tocEntry t WHERE t.bookId=b.id)
ORDER BY b.id LIMIT 40
