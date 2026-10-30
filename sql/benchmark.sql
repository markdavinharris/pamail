-- Comparison-year returns by VTD, cut at the same days before that year's Election Day.
-- {year}, {eday} and {project} are filled in by scripts/build_data.py.
-- q = on-demand (request date equals return date).
WITH d26 AS (SELECT ReturnDate, COUNT(*) n FROM `{project}.national_file.abev_2026`
        WHERE State='PA' AND ReturnDate IS NOT NULL GROUP BY 1),
c AS (SELECT MAX(ReturnDate) c26 FROM d26 WHERE n >= 1000),
cbt AS (SELECT DATE_SUB(DATE '{eday}', INTERVAL DATE_DIFF(DATE '2026-11-03', c26, DAY) DAY) cb FROM c),
b AS (SELECT DT_Regid, MAX(Democrat) d, MAX(Republican) r, MAX(IF(ReturnDate=RequestDate,1,0)) q FROM `{project}.national_file.abev_{year}`, cbt
      WHERE State='PA' AND ReturnDate <= cb AND IFNULL(Rejected,0)=0 GROUP BY 1),
vmap AS (SELECT DT_Regid, vtd_key FROM `{project}.national_file.pa_voter_vtd` WHERE vtd_key IS NOT NULL),
pmap AS (SELECT voter_county_name cn, voter_precinct_code pc, APPROX_TOP_COUNT(vtd_key,1)[OFFSET(0)].value vtd
         FROM `{project}.national_file.pa_voter_vtd` WHERE vtd_key IS NOT NULL GROUP BY 1,2),
vf AS (SELECT DT_Regid, CountyName, PrecinctCode FROM `{project}.national_file.voterfile_{year}` WHERE State='PA'),
pl AS (SELECT COALESCE(m.vtd_key, pm.vtd) vtd, b.d, b.r, b.q FROM b LEFT JOIN vmap m USING (DT_Regid)
       LEFT JOIN vf f ON m.vtd_key IS NULL AND f.DT_Regid=b.DT_Regid
       LEFT JOIN pmap pm ON pm.cn=f.CountyName AND pm.pc=f.PrecinctCode),
bal AS (SELECT vtd, COUNTIF(d=1) d, COUNTIF(d<>1 AND r=1) r, COUNTIF(d<>1 AND r<>1) o,
        COUNTIF(q=1 AND d=1) qd, COUNTIF(q=1 AND d<>1 AND r=1) qr, COUNTIF(q=1 AND d<>1 AND r<>1) qo FROM pl WHERE vtd IS NOT NULL GROUP BY 1)
SELECT ANY_VALUE(FORMAT_DATE('%F',cb)) cut, SUBSTR(vtd,3,3) cty,
  STRING_AGG(FORMAT('%s,%d,%d,%d,%d,%d,%d', SUBSTR(vtd,7), d, r, o, qd, qr, qo), ';') d
FROM bal, cbt GROUP BY cty ORDER BY cty
