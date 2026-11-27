SELECT b.id,b.title,b.totalLines,b.isBaseBook
FROM book b WHERE b.isBaseBook=1 AND b.totalLines BETWEEN 100 AND 10000
AND b.id > 177 AND b.id NOT IN (103,28,3152)
AND EXISTS (SELECT 1 FROM tocEntry t WHERE t.bookId=b.id)
ORDER BY b.id LIMIT 40
