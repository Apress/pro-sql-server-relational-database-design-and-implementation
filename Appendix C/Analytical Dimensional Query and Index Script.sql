USE [Chapter14];
GO

SELECT count(fcp.ClaimID) AS DeniedClaimCount
FROM fact.ClaimPayment fcp
INNER JOIN dim.AdjudicationType da        ON fcp.AdjudicationTypeKey=da.AdjudicationTypeKey
INNER JOIN dim.Date dd                    ON fcp.DateKey=dd.DateKey
WHERE da.AdjudicationCategory = 'DENIED'
AND dd.MonthValue = 7;

SELECT sum(fcp.DeniedCount) AS DeniedClaimCount
FROM fact.ClaimPayment fcp
INNER JOIN dim.Date dd                ON fcp.DateKey=dd.DateKey
WHERE dd.MonthValue = 7;

SELECT dp.OrganizationName, sum(fcp. AutoAdjudicatedCount) AS AutoAdjudicatedCount
FROM fact.ClaimPayment fcp
INNER JOIN dim.Provider dp      ON fcp.ProviderKey=dp.ProviderKey
GROUP BY dp.OrganizationName;

SELECT dp.OrganizationName,
dd.MonthValue,
sum(fcp. AutoAdjudicatedCount)/cast(count(ClaimID) as decimal(5,2))*100 AS AutoRatio
FROM fact.ClaimPayment fcp
INNER JOIN dim.Provider dp        ON fcp.ProviderKey=dp.ProviderKey
INNER JOIN dim.Date dd            ON fcp.DateKey=dd.DateKey
WHERE dd.DateValue between '01/01/2016' and '12/31/2016'
GROUP BY dp.OrganizationName, dd.MonthValue;

SELECT dd.DateValue, dm.InsuranceNumber, dat.AdjudicationType,
         dp.OrganizationName, ddiag.DiagnosisCode, dhcpc.ProcedureCode,
         SUM(fcp.ClaimAmount) AS ClaimAmount,
         SUM(fcp.AutoPayoutAmount) AS AutoPaymountAmount,
         SUM(fcp.ManualPayoutAmount) AS ManualPayoutAmount,
         SUM(fcp.AutoAdjudicatedCount) AS AutoAdjudicatedCount,
         SUM(fcp.ManualAdjudicatedCount) AS ManualAdjudicatedCount,
         SUM(fcp.AcceptedCount) AS AcceptedCount,
         SUM(fcp.DeniedCount) AS DeniedCount
FROM fact.ClaimPayment fcp
INNER JOIN dim.Date dd                          ON fcp.DateKey=dd.DateKey
INNER JOIN dim.Member dm                        ON fcp.MemberKey=dm.MemberKey
INNER JOIN dim.AdjudicationType dat ON fcp.AdjudicationTypeKey=dat.AdjudicationTypeKey
INNER JOIN dim.Provider dp                      ON fcp.ProviderKey=dp.ProviderKey
INNER JOIN dim.Diagnosis ddiag                  ON fcp.DiagnosisKey=ddiag.DiagnosisKey
INNER JOIN dim.HCPCSProcedure dhcpc             ON fcp.ProcedureKey=dhcpc.ProcedureKey
GROUP BY dd.DateValue, dm.InsuranceNumber, dat.AdjudicationType,
         dp.OrganizationName, ddiag.DiagnosisCode, dhcpc.ProcedureCode;

SELECT ProcedureKey, SUM(ClaimAmount) AS ClaimByProcedure
FROM fact.ClaimPayment
GROUP BY ProcedureKey;

CREATE NONCLUSTERED INDEX NonClusteredIndex ON fact.ClaimPayment
(
        ProcedureKey ASC
);
GO

CREATE NONCLUSTERED COLUMNSTORE INDEX ColumnStoreIndex ON fact.ClaimPayment
(
        DateKey,
        MemberKey,
        AdjudicationTypeKey,
        ProviderKey,
        DiagnosisKey,
        ProcedureKey,
        ClaimID,
        ClaimAmount,
        AutoPayoutAmount,
        ManualPayoutAmount,
        AutoAdjudicatedCount,
        ManualAdjudicatedCount,
        AcceptedCount,
        DeniedCount
);
GO
