// # Introduction

// This is a stub, beginning with the Factors_to_Consider_in_Managing_Chronic_Pain_R401_Test as a template
// to create colonoscopy surviellance logic, putting to test the data structure created in colon-poylp-data entry repo

// Proceeding from top to bottom will transform from pain to surveillance. 

// NOTE: This version of the testing and example purposes only. It is not ready for clinical use and never been testing
// in a live clinic scenario. 
//
// This logic takes a colon polyp diagnostic report and drills down into the details of each polyp 
// as a prelude to determining how soon the next surviellance colonoscopy should be performed 
// accoruding to American College of Gastroenterology (ACG) guidelines. For now I just want to see
// if one can drill down into the details with reasonable logic. 
// 
// I have no affilliation with the ACG. No one in the ACG is aware of this work, unless they happen 
// to have stumbled accross it in a repo search. 
//
// Likewise this work is based upon work by the CDS Connect Workgroup but there is no formal connection. 
//
// ##Source guideline: [Recommendations for Follow-Up After Colonoscopy and Polypectomy: A Consensus Update by the US Multi-Society Task Force on Colorectal Cancer](https://www.asge.org/docs/default-source/guidelines/recommendations-for-follow-up-after-colonoscopy-and-polypectomy-a-consensus-update-by-the-us-multi-society-task-force-on-colorectal-cancer-2020-march-gie.pdf?sfvrsn=2b0f8952_2)

library Colonoscopy_Next_Surveillance_R401 version '0.0.1'

// # Data model #

// The FHIR R4 model is used for testing purposes only.  It has not been piloted.
using FHIR version '4.0.1'

// # Referenced libraries #

// The CDS Connect Commons for FHIRv401 library provides functions representing commonly used CDS logic and patterns.
include CDS_Connect_Commons_for_FHIRv401 version '1.0.0' called C3F
// The FHIRHelpers library provides common functions for simplifying interaction w/ the FHIR R4 data model.
include FHIRHelpers version '4.0.1' called FHIRHelpers

// # Value sets and codes #

// ## Code Systems ##

codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMEDCT": 'http://snomed.info/sct'
codesystem "ICD-10-CM": 'http://hl7.org/fhir/sid/icd-10-cm'
codesystem "v2-0203": 'http://terminology.hl7.org/CodeSystem/v2-0203' // #MR Medical Record Number
codesystem "OBSCAT": 'http://terminology.hl7.org/CodeSystem/observation-category' // #procedure Procedure #laboratory Laboratory
codesystem "V3-ROLE-CODE": 'http://terminology.hl7.org/CodeSystem/v3-RoleCode' // #BRO brother
codesystem "v2-0074": 'http://terminology.hl7.org/CodeSystem/v2-0074' // #SP Surgical Pathology
codesystem "v2-0487": 'http://terminology.hl7.org/CodeSystem/v2-0487' // #POL Polyps
codesystem "ombCategory": 'urn:oid:2.16.840.1.113883.6.238' // #2106-3 White

// ## Value sets ##

// no values sets needed so far
// ## Individual codes ##

// list individual codes from code systems used directly in the CQL logic. Individual codes are used when there is
// a single code from a particular vocabulary standard used to represent a clinical concept. It is considered
// best-practice not to create value sets containing a single code.

// Discussion: I selected Tubular adenoma (disorder) over Tubular adenoma of colon (disorder) because 
// ... specimens may come from tne rectum which is part of the large intestine but not part of the colon.
// ... It would be nice to have a snomed code for Tubular adenoma of large intesting (disorder). 
// Benign tubular adenoma (morphologic abnormality) was also considered, but it is a subset of Body Structure, 
// ... which does not seem appropriate to me. 
code "Tubular adenoma": '444408007' from "SNOMEDCT" display 'Tubular adenoma (disorder)'
// or maybe it should be 'Benign tubular adenoma (morphologic abnormality) to be consistent with villous and tubulovillous adenoma; as in:
// code "Benign tubular adenoma": '1156654007' from "SNOMEDCT" display 'Benign tubular adenoma (morphologic abnormality) '
code "Hyperplastic polyp of intestine": '89452002' from "SNOMEDCT" display 'Hyperplastic polyp of intestine (disorder)'
code "Intestinal mucous membrane structure (body structure)": '68534000' from "SNOMEDCT" display 'Intestinal mucous membrane structure (body structure)'
code "Villous adenoma": '128859003' from "SNOMEDCT" display 'Villous adenoma (morphologic abnormality)'
code "Tubulovillous adenoma": '61722000' from "SNOMEDCT" display 'Tubulovillous adenoma (morphologic abnormality)'
// There is no Villous adenoma (disorder) or Tubulovillous adenoma (morphologic abnormality)
code "Severe dysplasia": '55237006' from "SNOMEDCT" display 'Severe dysplasia (morphologic abnormality)'
code "No evidence of malignant neoplasm": '110396000' from "SNOMEDCT" display 'No evidence of malignant neoplasm (finding)'
code "Piecemeal excision": '787139004' from "SNOMEDCT" display 'Piecemeal excision'
code "Fiberoptic colonoscopy with biopsy (procedure)": '25732003' from "SNOMEDCT" display  'Fiberoptic colonoscopy with biopsy (procedure)'
code "Colonoscopic polypectomy (procedure)": '311774002' from "SNOMEDCT" display 'Colonoscopic polypectomy (procedure)'
code "Excision - action": '129304002' from "SNOMEDCT" display 'Excision - action'
code "Large Intestine Polyp": '122645001' from "SNOMEDCT" display 'Polyp from large intestine obtained by polypectomy (specimen)'
code "Cecum structure (body structure)": '32713005' from "SNOMEDCT" display 'Cecum structure (body structure)'
code "Ascending colon structure (body structure)": '9040008' from "SNOMEDCT" display 'Ascending colon structure (body structure)'
code "Transverse colon structure (body structure)": '485005' from "SNOMEDCT" display 'Transverse colon structure (body structure)'
code "Descending colon structure (body structure)": '32622004' from "SNOMEDCT" display 'Descending colon structure (body structure)'
code "Sigmoid colon structure (body structure)": '60184004' from "SNOMEDCT" display 'Sigmoid colon structure (body structure)'
code "Rectum structure (body structure)": '34402009' from "SNOMEDCT" display 'Rectum structure (body structure)'
code "Medical Record Number": 'MR' from "v2-0203" display 'Medical Record Number'
code "Procedure": 'procedure' from "OBSCAT" display 'Procedure'
code "Laboratory": 'laboratory' from "OBSCAT" display 'Laboratory'
code "brother": 'BRO' from "V3-ROLE-CODE" display 'brother'
code "Surgical Pathology": 'SP' from "v2-0074" display 'Surgical Pathology'
code "Polyps": 'POL' from "v2-0487" display 'Polyps'
code "White": '2106-3' from "ombCategory" display 'White'
// LOINC#34574-4 Pathology report final diagnosis
code "Pathology report final diagnosis": '34574-4' from "LOINC" display 'Pathology report final diagnosis'
// LOINC#11529-5 Surgical pathology study
code "Surgical pathology study": '11529-5' from "LOINC" display 'Surgical pathology study'


// CQL currently requires concept declarations to contain references to code declarations.

// concept "Morphine Milligram Equivalent (MME)":
//   { "Morphine Milligram Equivalent (MME) code" } display 'Morphine Milligram Equivalent (MME)'

// # Parameters #

// The InclusionMedicationsLookbackPeriod allows CDS implementors to specify how far the inclusion logic should look
// back for qualifying active medications. By default, the inclusion logic will look back 180 days.
// parameter InclusionMedicationsLookbackPeriod default 180 days

// # CDS logic #

context Patient

// ## Re-usable functions ##

// The summary logic contains many constructs that are needed throughout the logic. Where possible, these constructs
// have been developed as re-usable functions that can be invoked wherever they are needed.

// Returns a text representation of a date using the CQL `ToString` function.
// @param d - a FHIR date to get text for
// @returns {System.String} the text representation of the date
define function DateText(d FHIR.date):
  ToString(d.value)

// Returns a text representation of a dateTime using the CQL `ToString` function.
// @param d - a FHIR dateTime to get text for
// @returns {System.String} the text representation of the dateTime
define function DateTimeText(d FHIR.dateTime):
  ToString(d.value)

// Returns a text representation of an instant using the CQL `ToString` function.
// @param i - a FHIR instant to get text for
// @returns {System.String} the text representation of the instant
define function InstantText(i FHIR.instant):
  ToString(i.value)

// Returns a text representation of a Quantity with the Quantity's value and unit.
// If the unit is {score}, then omit it (as it is not useful to display)
// @param q - a FHIR Quantity to get text for
// @returns {System.String} the text representation of the Quantity
define function QuantityText(q FHIR.Quantity):
  if (q is null) then null
  else if (q.unit is not null and q.unit.value != '{score}') then ToString(q.value.value) + ' ' + q.unit.value
  else if (q.code is not null and q.code.value != '{score}') then ToString(q.value.value) + ' ' + q.code.value
  else ToString(q.value.value)

// Returns a tuple containing a Period's start and end as text representations.
// @param p - a FHIR Period to get a tuple for
// @returns {Tuple<Start System.String, End System.String>} the tuple representation of the Period
define function PeriodObject(p FHIR.Period):
  if p is null then null
  else
    {
      Start: DateTimeText(p."start"),
      End: DateTimeText(p."end")
    }

// Returns a tuple containing a Range's low and high as text representations.
// @param r - a FHIR Range to get a tuple for
// @returns {Tuple<Low System.String, High System.String>} the tuple representation of the Range
define function RangeObject(r FHIR.Range):
  if r is null then null
  else
    {
      Low: QuantityText(r.low),
      High: QuantityText(r.high)
    }

// Returns a text representation of a date associated with an Observation, preferring `effectiveDateTime`, then
// `effectivePeriod.start`, then `issued`.
// @param o - a FHIR Observation to get the text date from
// @returns {System.String} the text representation of a relevant date from the Observation
define function ObservationDate(o FHIR.Observation):
  Coalesce(
    DateTimeText(o.effective as FHIR.dateTime),
    InstantText(o.effective as FHIR.instant),
    DateTimeText((o.effective as FHIR.Period)."start"),
    InstantText(o.issued)
  )

// Returns a text representation of a date associated with a MedicationStatement, preferring `effectiveDateTime`, then
// `.start`.
// @param s - a FHIR MedicationStatement to get the text date from
// @returns {System.String} the text representation of a relevant date from the MedicationStatement
define function MedicationStatementDate(s FHIR.MedicationStatement):
  Coalesce(
    DateTimeText(s.effective as FHIR.dateTime),
    DateTimeText((s.effective as FHIR.Period)."start")
  )

// Returns a text representation of a Condition's onset, whether represented as a dateTime, Period, Quantity (Age),
// Range (Age), or string.
// @param c - a FHIR Condition to get the text representation of the onset from
// @returns {System.String} the text representation of the Condition's onset
define function Onset(c FHIR.Condition):
  Coalesce( List{
    DateTimeText(c.onset as FHIR.dateTime),
    QuantityText(c.onset as FHIR.Age),
    PeriodObject(c.onset as FHIR.Period),
    RangeObject(c.onset as FHIR.Range),
    (c.onset as FHIR.string).value
  })

// Returns a text representation of a Condition's abatement, whether represented as a dateTime, Period, Quantity (Age),
// Range (Age), string, or boolean.
// @param c - a FHIR Condition to get the text representation of the abatement from
// @returns {System.String} the text representation of the Condition's abatement
define function Abatement(c FHIR.Condition):
  Coalesce( List{
    DateTimeText(c.abatement as FHIR.dateTime),
    QuantityText(c.abatement as FHIR.Age),
    PeriodObject(c.abatement as FHIR.Period),
    RangeObject(c.abatement as FHIR.Range),
    (c.abatement as FHIR.string).value
  })

// ## Target population ##

// INCLUSIONS

// Determines if patient's age, in years, at the time CQL is run, is at least 18 years old
define Is18orOlder:
  AgeInYears() >= 18

// INCLUSIONS

// Determines if the patient meets the inclusion criteria for the CDS. 

// EXCLUSIONS

// colon cancer here

// Encounter diagnoses that are risk factors for opioid-related harms and their dates of onset. Some risk factors may
// not exist on the problem list, and therefore may not be represented as Conditions (depending on EHR implementation).
// For this, the logic also looks at the patient's encounters, trying to find risk factors recorded as encounter
// diagnosis codes. We do not look at the reasonReference field because the Conditions referred to would already be
// reflected in the expression that queries over Conditions.


// Shape the pregnancy Observation as a Condition, since this is the backup approach for detecting a pregnancy in case
// there are no active Conditions found.
// define ReportMostRecentPositivePregnancyObservation:
//   if MostRecentPregnancyObservationIsPositive then
//     {
//       Name: ConceptText(MostRecentPregnancyObservation.code),
//       Status: ConceptText(MostRecentPregnancyObservation.value as FHIR.CodeableConcept),
//       Onset: ToString(Coalesce(
//         (MostRecentPregnancyObservation.effective as FHIR.dateTime).value,
//         (MostRecentPregnancyObservation.effective as FHIR.instant).value,
//         (MostRecentPregnancyObservation.effective as FHIR.Period)."start".value
//       )),
//       DateRecorded: ToString(MostRecentPregnancyObservation.issued.value),
//       Abatement: null as String,
//       Visit: null as Tuple{ Start String, End String }
//     }
//   else
//     null

// Shape the case of being 65 or older as a Condition for the purposes of building the summary.
// define ReportOlderThan65:
//   if Is65orOlder then
//     {
//       Name: '65 years or older',
//       Status: 'active',
//       Onset: null as String,
//       DateRecorded: null as String,
//       Abatement: null as String,
//       Visit: null as Tuple{ Start String, End String }
//     }
//   else
//     null

// RISK CONSIDERATIONS

// find the Diagnostic Reports

define SurgicalPathologyReport:
  [DiagnosticReport: "Surgical pathology study"]

define SurgicalPathologyPolypReport:
  [DiagnosticReport: "Large Intestine Polyp"]

define TotalLifetimePolyps: 
  Count(SurgicalPathologyPolypReport.specimen)

/**
 * The most recent diagnostic report.  For each  diagnostic report, this algorithm will use the Coalesce function, which returns the
 * first non-null result from these fields: performedDateTime, performedPeriod.end, performedPeriod.start.
 * The found date will be used to compare  diagnostic report and determine the most recent one.
 * @param DxReporList - a list of Procedures
 * @returns {DiagnosticReport} the most recent diagnostic report from the list, or null if null was passed in
 */
define MostRecentDiagnosticReport:
  Last(SurgicalPathologyPolypReport PR sort by issued)

define MostRecentPolypCount:
  Count(MostRecentDiagnosticReport.specimen)

define PolypHistopath:
  MostRecentDiagnosticReport.result[0]

// define FinalDiagnosis:
//   [Observation: "Pathology report final diagnosis"] O
//     with [Observation: "Large Intestine Polyp"] P
//       such that O.id in P.hasMember // no no no

// define ObservationMembers:
//   [Observation] O
//   return all O.hasMember

// define ReferencedProcedure:
//   [Procedure] P
//     with [Procedure: "Fiberoptic colonoscopy with biopsy (procedure)"] Q
//       such that P.status = Q.status

// define ReferencedDiagnosticReport:
//   [DiagnosticReport] DR
//     with [Specimen] S
//       such that SubString( PositionOf('/', DR.specimen[0].reference ), DR.specimen[0].reference )  = S.id

// this exposes the id of the first specimen in a DiagnosticReport of a given date
define ReferencedDiagnosticReport:
  singleton from ( [DiagnosticReport] DR
    where DR.effective as dateTime = @2019-07-22T00:00:00.000Z
    return Split( DR.specimen[0].reference.value ,'/' )[1] )

// same without singleton and no splitting
define ReferencedDiagnosticReport1:
  First( [DiagnosticReport] DR
    where DR.effective as dateTime = @2019-07-22T00:00:00.000Z
    return DR.specimen.reference.value)

// define ParsedReferencedDiagnosticReport1:
//   Split( ReferencedDiagnosticReport1,'/' )[1]

// at least selects the right number of specimens and maybe the right ones
define SpecimenFromACertainDatedReport:
  [Specimen] S
  with ReferencedDiagnosticReport1 R
  such that ('Specimen/' + S.id) in R

define MostRecentColonoscopyPolypDiagnosticReport:
  Last([DiagnosticReport: "Large Intestine Polyp"])

define SpecimenListFromMostRecentColonoscopyPolypDiagnosticReport:
  MostRecentColonoscopyPolypDiagnosticReport DR
  return DR.specimen.reference.value
 
define SpecimensFromMostRecentColonoscopyPolypDiagnosticReport:
  [Specimen] S
  with SpecimenListFromMostRecentColonoscopyPolypDiagnosticReport SL
  such that ('Specimen/' + S.id) in SL

define ResultListFromMostRecentColonoscopyPolypDiagnosticReport:
  MostRecentColonoscopyPolypDiagnosticReport DR
  return DR.result.reference.value
 
define ResultsFromMostRecentColonoscopyPolypDiagnosticReport:
  [Observation: "Large Intestine Polyp"] O
  with ResultListFromMostRecentColonoscopyPolypDiagnosticReport RL
  such that ('Observation/' + O.id) in RL
  // return Tuple {oId: O.id, oMember: O.hasMember[0].display}

define X:
  from SpecimensFromMostRecentColonoscopyPolypDiagnosticReport S, ResultsFromMostRecentColonoscopyPolypDiagnosticReport R
  where ( 'Specimen/' + S.id ) = R.specimen.reference
  return Tuple {
    specimenId: S.id, 
    resultId: R.id, 
    polypSize: S.collection.quantity,
    resultMembers: R.hasMember
  }

// define Y:
  // [Observation: "Pathology report final diagnosis"] O
//   with X X such that ('Observation/' + O.id) = X.resultMembers[0].reference

define Y: 
  from [Observation: "Pathology report final diagnosis"] O, X X
  where ('Observation/' + O.id) = X.resultMembers[0].reference
  return all Tuple { finalPathology: O.value }

// try to combine X and Y
// define XandY: 
//     from SpecimensFromMostRecentColonoscopyPolypDiagnosticReport S, 
//          ResultsFromMostRecentColonoscopyPolypDiagnosticReport R, 
//         [Observation: "Pathology report final diagnosis"] O, 
//         X X    
//     where ( 'Specimen/' + S.id ) = R.specimen.reference and      
//           ( 'Observation/' + O.id ) = X.resultMembers[0].reference and

//     return all Tuple {
//       specimenId: S.id, 
//       resultId: R.id, 
//       polypSize: S.collection.quantity,
//       finalPathology: O.value
//     }

// expand Y
define Yexpanded:
  from [ Observation: "Pathology report final diagnosis" ] FD, 
       [ Observation: "Piecemeal excision" ] PE, 
       [ Observation: "Severe dysplasia" ] SD, 
       [ Observation: "No evidence of malignant neoplasm" ] NMN, 
       X X
  where ( 'Observation/' + FD.id ) = X.resultMembers[0].reference and
        ( 'Observation/' + PE.id ) = X.resultMembers[1].reference and
        ( 'Observation/' + SD.id ) = X.resultMembers[2].reference and
        ( 'Observation/' + NMN.id ) = X.resultMembers[3].reference 
  return all Tuple { 
    polypSize: X.polypSize,
    finalPathology: FD.value,
    piecemealExcision: PE.value,
    severeDysplasia: SD.value,
    noEvidenceOfMalignantNeoplasm: NMN.value
  }

define TubularAdenomas:
  Yexpanded YE where YE.finalPathology ~ "Tubular adenoma"
  return all YE

define NumberOfTubularAdenomas:
  Count(TubularAdenomas)

define NumberOfVillousAdenomas: 
  Count(
    Yexpanded YE where YE.finalPathology ~ "Villous adenoma"
    return all YE
    )

define NumberOfTubulovillousAdenomas: 
  Count(
    Yexpanded YE where YE.finalPathology ~ "Tubulovillous adenoma"
    return all YE
  )

define NumberOfAdenomas: 
   NumberOfTubularAdenomas + NumberOfVillousAdenomas + NumberOfTubulovillousAdenomas

define NumberOfHyperplasticPolyps:
  Count(
    Yexpanded YE where YE.finalPathology ~ "Hyperplastic polyp of intestine"
    return all YE    
    )

// LTE <= less than or equal to
define NumberOfTubularAdenomasLTE10mm:
  Count( 
    Yexpanded YE where 
      YE.finalPathology ~ "Tubular adenoma" and
      YE.polypSize <= 10 'mm' 
      return all YE
    )

define AnyPolypWithVillousOrTubulovillousHistolgy:
  (NumberOfVillousAdenomas + NumberOfTubulovillousAdenomas) > 0

define AnyAdenomaWithHighGradeDysplasia:
  Count(
      Yexpanded YE where 
      ( YE.finalPathology ~ "Tubular adenoma" or
      YE.finalPathology ~ "Villous adenoma" or
      YE.finalPathology ~ "Tubulovillous adenoma" ) and
      YE.severeDysplasia = true 
      return all YE
    ) > 0

// GTE means greater than or equal to
define AnyAdenomaGTE20mmAndPiecemealResection:
  Count(
      Yexpanded YE where 
      ( YE.finalPathology ~ "Tubular adenoma" or
      YE.finalPathology ~ "Villous adenoma" or
      YE.finalPathology ~ "Tubulovillous adenoma" ) and
      YE.polypSize >= 20 'mm' and 
      YE.piecemealExcision = true
      return all YE
    ) > 0

define AnyAdenomaGTE10mm: 
  Count(
      Yexpanded YE where 
      ( YE.finalPathology ~ "Tubular adenoma" or
      YE.finalPathology ~ "Villous adenoma" or
      YE.finalPathology ~ "Tubulovillous adenoma" ) and
      YE.polypSize >= 10 'mm' 
      return all YE
    ) > 0

  define NextColonoscopyIntervals: 
    // {
    //   if ( 
    //     NumberOfTubularAdenomasLTE10mm > 0 and NumberOfTubularAdenomasLTE10mm < 3 ) then Interval[ 7.0, 10.0 ] else Interval[10.0, 10.0], 
    //   if ( NumberOfTubularAdenomasLTE10mm > 2 and NumberOfTubularAdenomasLTE10mm < 5 ) then Interval[ 3.0, 5.0 ] else Interval[ 10.0, 10.0 ],
    //   if ( NumberOfTubularAdenomasLTE10mm > 4 and NumberOfTubularAdenomasLTE10mm < 11 ) then 3 else 10,
    //   if AnyAdenomaGTE10mm = true then 3 else 10,
    //   if AnyPolypWithVillousOrTubulovillousHistolgy = true then 3 else 10,
    //   if AnyAdenomaWithHighGradeDysplasia = true then 3 else 10,
    //   if NumberOfAdenomas > 10 then 1 else 10,
    //   if AnyAdenomaGTE20mmAndPiecemealResection = true then 0.5 else 10
    // }
    //     {
    //   if ( NumberOfTubularAdenomasLTE10mm > 0 and NumberOfTubularAdenomasLTE10mm < 3 ) then Tuple{ 7, '7-10' }
    //   if ( NumberOfTubularAdenomasLTE10mm > 2 and NumberOfTubularAdenomasLTE10mm < 5 ) then Tuple{ 3, '3-5'}
    //   if ( NumberOfTubularAdenomasLTE10mm > 4 and NumberOfTubularAdenomasLTE10mm < 11 ) then 3 else 10,
    //   if AnyAdenomaGTE10mm = true then 3 else 10,
    //   if AnyPolypWithVillousOrTubulovillousHistolgy = true then 3 else 10,
    //   if AnyAdenomaWithHighGradeDysplasia = true then 3 else 10,
    //   if NumberOfAdenomas > 10 then 1 else 10,
    //   if AnyAdenomaGTE20mmAndPiecemealResection = true then 0.5 else 10
    // }
    {
      if ( 
        NumberOfTubularAdenomasLTE10mm > 0 and NumberOfTubularAdenomasLTE10mm < 3 ) then Interval[ 7.0, 10.0 ] else Interval[10.0, 10.0], 
      if ( NumberOfTubularAdenomasLTE10mm > 2 and NumberOfTubularAdenomasLTE10mm < 5 ) then Interval[ 3.0, 5.0 ] else Interval[ 10.0, 10.0 ],
      if ( NumberOfTubularAdenomasLTE10mm > 4 and NumberOfTubularAdenomasLTE10mm < 11 ) then Interval[ 3.0, 3.0 ] else Interval[ 10.0, 10.0 ],
      if AnyAdenomaGTE10mm = true then Interval[ 3.0, 3.0 ] else Interval[ 10.0, 10.0 ],
      if AnyPolypWithVillousOrTubulovillousHistolgy = true then Interval[ 3.0, 3.0 ] else Interval[ 10.0, 10.0 ],
      if AnyAdenomaWithHighGradeDysplasia = true then Interval[ 3.0, 3.0 ] else Interval[ 10.0, 10.0 ],
      if NumberOfAdenomas > 10 then Interval[ 1.0, 1.0 ] else Interval[ 10.0, 10.0 ],
      if AnyAdenomaGTE20mmAndPiecemealResection = true then Interval[ 0.5, 0.5 ] else Interval[ 10.0, 10.0 ]
    }

// THE SECTION ABOVE REALLY NEEDS TO BE TESTED!!!

// this is not done.....
define NextColonoscopyInterval:
  Min(NextColonoscopyIntervals.low)