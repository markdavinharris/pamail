-- 2026 PA mail ballot returns and current registration by 2020 Census VTD.
-- Cutoff: latest 2026 return date with >= 1,000 ballots logged.
WITH d26 AS (SELECT ReturnDate, COUNT(*) n FROM `{project}.national_file.abev_2026`
        WHERE State='PA' AND ReturnDate IS NOT NULL GROUP BY 1),
c AS (SELECT MAX(ReturnDate) c26 FROM d26 WHERE n >= 1000),
b AS (SELECT DT_Regid, MAX(Democrat) d, MAX(Republican) r FROM `{project}.national_file.abev_2026`, c
      WHERE State='PA' AND ReturnDate <= c26 AND IFNULL(Rejected,0)=0 GROUP BY 1),
vmap AS (SELECT DT_Regid, vtd_key FROM `{project}.national_file.pa_voter_vtd` WHERE vtd_key IS NOT NULL),
bal AS (SELECT m.vtd_key vtd, COUNTIF(b.d=1) d, COUNTIF(b.d<>1 AND b.r=1) r, COUNTIF(b.d<>1 AND b.r<>1) o
        FROM b JOIN vmap m USING (DT_Regid) GROUP BY 1),
reg AS (SELECT m.vtd_key vtd,
    COUNTIF(v.PartyRollUp='Democrat') rd, COUNTIF(v.PartyRollUp='Republican') rr, COUNT(*) ra,
    APPROX_TOP_COUNT(v.CongressionalDistrict,1)[OFFSET(0)].value cd,
    APPROX_TOP_COUNT(v.StateSenateDistrict,1)[OFFSET(0)].value sd,
    APPROX_TOP_COUNT(v.StateHouseDistrict,1)[OFFSET(0)].value hd
  FROM vmap m JOIN `{project}.national_file.voters` v USING (DT_Regid) WHERE v.State='PA' GROUP BY 1),
j AS (SELECT vtd, r.rd, r.rr, r.ra, r.cd, r.sd, r.hd, IFNULL(b.d,0) d, IFNULL(b.r,0) r_, IFNULL(b.o,0) o
      FROM reg r FULL JOIN bal b USING (vtd))
SELECT ANY_VALUE(FORMAT_DATE('%F',c26)) cut, SUBSTR(vtd,3,3) cty,
  STRING_AGG(FORMAT('%s,%d,%d,%d,%d,%d,%d,%s,%s,%s', SUBSTR(vtd,7), d, r_, o,
    IFNULL(rd,0), IFNULL(rr,0), IFNULL(ra,0), IFNULL(cd,''), IFNULL(sd,''), IFNULL(hd,'')), ';') d
FROM j, c GROUP BY cty ORDER BY cty
