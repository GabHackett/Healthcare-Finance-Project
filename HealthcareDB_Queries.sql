USE Healthcare_DB

/*1. How many unique patients exist is the Healthcare_DB? */

SELECT
	COUNT(DISTINCT PatientNumber) AS unique_patients
FROM dimPatient


/*2. Categorize patients by age group. */

SELECT 
	COUNT(DISTINCT PatientNumber) AS num_of_patients,
	(CASE WHEN PatientAge < 18 THEN '0-17'
			WHEN PatientAge BETWEEN 18 AND 29 THEN '18-29'
			WHEN PatientAge BETWEEN 30 AND 39 THEN '30-39'
			WHEN PatientAge BETWEEN 40 AND 54 THEN '40-54'
			WHEN PatientAge BETWEEN 55 AND 64 THEN '55-64'
			WHEN PatientAge BETWEEN 65 AND 74 THEN '65-74'
			 ELSE '75+' END) age_group
FROM dimPatient
GROUP BY
(CASE WHEN PatientAge < 18 THEN '0-17'
			WHEN PatientAge BETWEEN 18 AND 29 THEN '18-29'
			WHEN PatientAge BETWEEN 30 AND 39 THEN '30-39'
			WHEN PatientAge BETWEEN 40 AND 54 THEN '40-54'
			WHEN PatientAge BETWEEN 55 AND 64 THEN '55-64'
			WHEN PatientAge BETWEEN 65 AND 74 THEN '65-74'
			 ELSE '75+' END) 

/*3. Count patients by gender. */

SELECT 
	PatientGender,
	COUNT(DISTINCT PatientNumber) AS num_by_gen
FROM dimPatient
GROUP BY PatientGender


/* 4. Count patients by location. */

SELECT 
	LocationName,
	COUNT(DISTINCT PatientNumber) AS Num_of_patients
FROM dimLocation
INNER JOIN FactTable
	ON FactTable.dimLocationPK = dimLocation.dimLocationPK
GROUP BY LocationName


/* 5. Provide a financial summary for each location*/
SELECT
	LocationName,
	FORMAT(GrossCharges, '$#,#') AS GrossCharges,
	FORMAT(ContractualAdj, '$#,#') AS ContractualAdj,
	FORMAT(NetCharges, '$#,#') AS NetCharges,
	FORMAT(Payments, '$#,#') AS Payments,
	FORMAT(Adjustments-ContractualAdj, '$#,#') AS Adjustments,
	FORMAT(-(Payments)/(GrossCharges),'P0') AS GrossCollectionRate,
	FORMAT(-Payments/NetCharges, 'P0') AS NetCollectionRate,
	FORMAT(AR, '$#,#') AS AR,
	FORMAT(AR/NetCharges, 'P0') AS PercentinAR,
	FORMAT(-(Adjustments-ContractualAdj)/NetCharges, 'P0') AS WriteOffPercent
FROM
	(SELECT
		LocationName,
		SUM(GrossCharge) AS GrossCharges,
		SUM(CASE WHEN AdjustmentReason = 'Contractual' THEN Adjustment ELSE NULL END) AS 'ContractualAdj',
		SUM(GrossCharge) + SUM(CASE WHEN AdjustmentReason = 'Contractual' THEN Adjustment ELSE NULL END) AS 'NetCharges',
		SUM(Payment) AS Payments,
		SUM(Adjustment) AS Adjustments,
		SUM(AR) AS AR
	FROM 
		FactTable
	INNER JOIN dimLocation
		ON dimLocation.dimLocationPK = FactTable.dimLocationPK
	INNER JOIN dimTransaction
		ON dimTransaction.dimTransactionPK = FactTable.dimTransactionPK
	GROUP BY LocationName) AS a
ORDER BY NetCollectionRate 


/*6. Provide a financial summary for each specialty*/
SELECT
	ProviderSpecialty,
	FORMAT(GrossCharges, '$#,#') AS GrossCharges,
	FORMAT(ContractualAdj, '$#,#') AS ContractualAdj,
	FORMAT(NetCharges, '$#,#') AS NetCharges,
	FORMAT(-Payments, '$#,#') AS Payments,
	FORMAT(Adjustments-ContractualAdj, '$#,#') AS Adjustments,
	FORMAT(-Payments/NULLIF(GrossCharges, 0) ,'P0') AS GrossCollectionRate,
	FORMAT(-Payments/NetCharges, 'P0') AS NetCollectionRate,
	FORMAT(AR, '$#,#') AS AR,
	FORMAT(AR/NetCharges, 'P0') AS PercentinAR,
	FORMAT(-(Adjustments-ContractualAdj)/NetCharges, 'P0') AS WriteOffPercent
FROM
	(SELECT
		ProviderSpecialty,
		SUM(GrossCharge) AS GrossCharges,
		SUM(CASE WHEN AdjustmentReason = 'Contractual' THEN Adjustment ELSE NULL END) AS 'ContractualAdj',
		SUM(GrossCharge) + SUM(CASE WHEN AdjustmentReason = 'Contractual' THEN Adjustment ELSE NULL END) AS 'NetCharges',
		SUM(Payment) AS Payments,
		SUM(Adjustment) AS Adjustments,
		SUM(AR) AS AR
	FROM 
		FactTable
	INNER JOIN dimPhysician
		ON dimPhysician.dimPhysicianPK = FactTable.dimPhysicianPK
	INNER JOIN dimTransaction
		ON dimTransaction.dimTransactionPK = FactTable.dimTransactionPK
	GROUP BY ProviderSpecialty) AS a
ORDER BY NetCollectionRate DESC


/* 7. What are the most frequent DiagnosisCodeGroups by total CPT Units? How does this differ by the number of patients?*/
SELECT
	DiagnosisCodeGroup,
	SUM(CptUnits) AS tot_CptUnits,
	COUNT(DISTINCT PatientNumber) AS num_of_patients,
	FORMAT(SUM(CptUnits)/COUNT(DISTINCT PatientNumber),'#') AS cptunits_per_patient
FROM FactTable
INNER JOIN dimDiagnosisCode
	ON dimDiagnosisCode.dimDiagnosisCodePK = FactTable.dimDiagnosisCodePK
INNER JOIN dimCptCode
	ON FactTable.dimCPTCodePK = dimCptCode.dimCPTCodePK
GROUP BY
	DiagnosisCodeGroup
ORDER BY 2 DESC

/* 8. Which physician specialty that has received the highest amount of payments? */

SELECT
	ProviderSpecialty,
	-SUM(Payment) AS tot_payments,
	COUNT(Payment) AS count_of_payments
FROM dimPhysician
INNER JOIN FactTable
	ON dimPhysician.dimPhysicianPK = FactTable.dimPhysicianPK
GROUP BY ProviderSpecialty
ORDER BY 2 DESC

/*9. Summarize total payments by specific payer.*/

SELECT
	PayerName,
	FORMAT(SUM(-Payment),'$#,#.##') AS Total_Payment
FROM FactTable
INNER JOIN dimPayer
	ON FactTable.dimPayerPK = dimPayer.dimPayerPK
GROUP BY PayerName
ORDER BY 2 DESC


/* 10. What are the average charges per patient and per physician?*/

SELECT
	FORMAT(SUM(GrossCharge)/COUNT(DISTINCT PatientNumber), '$#,#.##') AS ChargePerPatient,
	FORMAT(SUM(GrossCharge)/COUNT(DISTINCT dimPhysicianPK), '$#,#.##') AS ChargePerPhysician
FROM FactTable
