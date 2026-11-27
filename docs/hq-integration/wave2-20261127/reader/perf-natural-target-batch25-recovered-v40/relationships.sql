
WITH win(id) AS (SELECT id FROM line WHERE bookId=?),
matched(linkId,matchedSide,anchorLineId) AS (
 SELECT id,0,sourceLineId FROM link WHERE sourceBookId=? AND sourceLineId IN (SELECT id FROM win)
 UNION SELECT link.id,0,c.lineId FROM link_coverage c JOIN link ON link.id=c.linkId
       WHERE c.side=0 AND link.sourceBookId=? AND c.lineId IN (SELECT id FROM win)
 UNION SELECT id,1,targetLineId FROM link WHERE targetBookId=? AND targetLineId IN (SELECT id FROM win)
 UNION SELECT link.id,1,c.lineId FROM link_coverage c JOIN link ON link.id=c.linkId
       WHERE c.side=1 AND link.targetBookId=? AND c.lineId IN (SELECT id FROM win)
), resolved AS (
 SELECT DISTINCT link.id AS linkId,matched.anchorLineId,
   CASE matched.matchedSide WHEN 0 THEN link.targetLineId ELSE link.sourceLineId END AS linkedLineId,
   CASE matched.matchedSide WHEN 0 THEN link.targetBookId ELSE link.sourceBookId END AS linkedBookId
 FROM matched JOIN link ON link.id=matched.linkId
 LEFT JOIN connection_type ON connection_type.id=link.connectionTypeId
 WHERE (matched.matchedSide=0 AND NOT EXISTS (
   SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=0))
 OR (matched.matchedSide=1 AND connection_type.name IN ('COMMENTARY','SUPER_COMMENTARY','TARGUM','MIDRASH','PARSHANUT','DIBUR_HAMATCHIL','ELUCIDATION','EXPLICATION','FOOTNOTES','REFERENCE','QUOTATION','MESORAT_HASHAS','EIN_MISHPAT','MISHNAH_IN_TALMUD','RELATED','OTHER','SIFREI_MITZVOT','ESSAY','ALLUSION','LITURGY','LAW','SUMMARY')
   AND NOT EXISTS (SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=1)
   AND (link.sourceBookId!=link.targetBookId OR (
     connection_type.name IN ('REFERENCE','QUOTATION','MESORAT_HASHAS','EIN_MISHPAT','MISHNAH_IN_TALMUD','RELATED','OTHER','SIFREI_MITZVOT','ESSAY','ALLUSION','LITURGY','LAW','SUMMARY') AND (
       EXISTS (SELECT 1 FROM link_suppressed_side h WHERE h.linkId=link.id AND h.side=0)
       OR (matched.anchorLineId!=link.sourceLineId AND NOT EXISTS (
         SELECT 1 FROM link_coverage c WHERE c.linkId=link.id AND c.side=0 AND c.lineId=matched.anchorLineId))
     )
   )))
)
SELECT resolved.linkId,resolved.linkedBookId,resolved.linkedLineId,resolved.anchorLineId
FROM resolved JOIN line linked_line ON linked_line.id=resolved.linkedLineId
JOIN book linked_book ON linked_book.id=resolved.linkedBookId
