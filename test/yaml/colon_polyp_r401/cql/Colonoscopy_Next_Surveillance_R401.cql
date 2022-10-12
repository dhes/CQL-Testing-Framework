// # Introduction

// NOTE: This version of the testing and example purposes only. It is not ready for clinical use and never been testing
// in a live clinic scenario. 
//
// This logic takes a colon polyp diagnostic report and drills down into the details of each polyp 
// as a prelude to determining how soon the next surviellance colonoscopy should be performed 
// accoruding to guidelines. 
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
code "Excision": '65801008' from "SNOMEDCT" display 'Excision (procedure)' // meaning 'non-piecemeal excision' or 'whole excision'
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
// the next one is due to change in data model Sept-2022
code "Histopathology Finding": '250537006' from "SNOMEDCT" display 'Histopathology finding (finding)'
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

// ## Target population ##

// INCLUSIONS

// Determines if patient's age, in years, at the time CQL is run, is at least 18 years old
define Is18orOlder:
  AgeInYears() >= 18

// INCLUSIONS

// Determines if the patient meets the inclusion criteria for the CDS. 

// EXCLUSIONS

// colon cancer here

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
  [Observation: "Histopathology Finding"] O
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
		collectionMethod: S.collection.method,  // added 10-05-2022 DH was previously in Result
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
      //  [ Observation: "Piecemeal excision" ] PE, // DH 10-05-2022 moved to Specimen.collection.method
       [ Observation: "Severe dysplasia" ] SD, 
       [ Observation: "No evidence of malignant neoplasm" ] NMN, 
       X X
  where ( 'Observation/' + FD.id ) = X.resultMembers[0].reference and
        // ( 'Observation/' + PE.id ) = X.resultMembers[1].reference and
        ( 'Observation/' + SD.id ) = X.resultMembers[1].reference and
        ( 'Observation/' + NMN.id ) = X.resultMembers[2].reference 
  return all Tuple { 
    polypSize: X.polypSize,
    finalPathology: FD.value,
    // piecemealExcision: PE.value, // DH 10-05-2022 moved to Specimen.collection.method
		piecemealExcision: if (X.collectionMethod ~ "Piecemeal excision") then true else false,
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

define AnyPolypWithVillousOrTubulovillousHistology:
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

// ColonoscopyInterval means the time ineterval at which the next colonoscopy should be performed.

  // define NextColonoscopyIntervals: 
    // {
    //   if ( 
    //     NumberOfTubularAdenomasLTE10mm > 0 and NumberOfTubularAdenomasLTE10mm < 3 ) then Interval[ 7.0, 10.0 ] else Interval[10.0, 10.0], 
    //   if ( NumberOfTubularAdenomasLTE10mm > 2 and NumberOfTubularAdenomasLTE10mm < 5 ) then Interval[ 3.0, 5.0 ] else Interval[ 10.0, 10.0 ],
    //   if ( NumberOfTubularAdenomasLTE10mm > 4 and NumberOfTubularAdenomasLTE10mm < 11 ) then 3 else 10,
    //   if AnyAdenomaGTE10mm = true then 3 else 10,
    //   if AnyPolypWithVillousOrTubulovillousHistology = true then 3 else 10,
    //   if AnyAdenomaWithHighGradeDysplasia = true then 3 else 10,
    //   if NumberOfAdenomas > 10 then 1 else 10,
    //   if AnyAdenomaGTE20mmAndPiecemealResection = true then 0.5 else 10
    // }
    //     {
    //   if ( NumberOfTubularAdenomasLTE10mm > 0 and NumberOfTubularAdenomasLTE10mm < 3 ) then Tuple{ 7, '7-10' }
    //   if ( NumberOfTubularAdenomasLTE10mm > 2 and NumberOfTubularAdenomasLTE10mm < 5 ) then Tuple{ 3, '3-5'}
    //   if ( NumberOfTubularAdenomasLTE10mm > 4 and NumberOfTubularAdenomasLTE10mm < 11 ) then 3 else 10,
    //   if AnyAdenomaGTE10mm = true then 3 else 10,
    //   if AnyPolypWithVillousOrTubulovillousHistology = true then 3 else 10,
    //   if AnyAdenomaWithHighGradeDysplasia = true then 3 else 10,
    //   if NumberOfAdenomas > 10 then 1 else 10,
    //   if AnyAdenomaGTE20mmAndPiecemealResection = true then 0.5 else 10
    // }
    // {
    //   if ( 
    //     NumberOfTubularAdenomasLTE10mm > 0 and NumberOfTubularAdenomasLTE10mm < 3 ) then Interval[ 7.0, 10.0 ] else Interval[10.0, 10.0], 
    //   if ( NumberOfTubularAdenomasLTE10mm > 2 and NumberOfTubularAdenomasLTE10mm < 5 ) then Interval[ 3.0, 5.0 ] else Interval[ 10.0, 10.0 ],
    //   // Interval[ 3.0, 5.0 ],
    //   if ( NumberOfTubularAdenomasLTE10mm > 4 and NumberOfTubularAdenomasLTE10mm < 11 ) then Interval[ 3.0, 3.0 ] else Interval[ 10.0, 10.0 ],
    //   if AnyAdenomaGTE10mm = true then Interval[ 3.0, 3.0 ] else Interval[ 10.0, 10.0 ],
    //   if AnyPolypWithVillousOrTubulovillousHistology = true then Interval[ 3.0, 3.0 ] else Interval[ 10.0, 10.0 ],
    //   if AnyAdenomaWithHighGradeDysplasia = true then Interval[ 3.0, 3.0 ] else Interval[ 10.0, 10.0 ],
    //   if NumberOfAdenomas > 10 then Interval[ 1.0, 1.0 ] else Interval[ 10.0, 10.0 ],
    //   if AnyAdenomaGTE20mmAndPiecemealResection = true then Interval[ 0.5, 0.5 ] else Interval[ 10.0, 10.0 ]
    // }


// The next three defines are not totally intuitive. Please test it yourself
// The question arises what if we have a point-in-time recommendation (e.g. 1 year) and an interval
// ...recommendation (e.g. 1/2 year to 2 years). The answer in this instance is 1/2-1 year. That interval
// ...in general should be Minimum(lower bounds) to Minimum(upper bounds). 
define NextColonoscopyIntervalLowerBound:
    {
      if ( NumberOfTubularAdenomasLTE10mm > 0 and NumberOfTubularAdenomasLTE10mm < 3 ) then 7.0 else 10.0,  // 7 - 10 years
      if ( NumberOfTubularAdenomasLTE10mm > 2 and NumberOfTubularAdenomasLTE10mm < 5 ) then 3.0 else 10.0,  // 3-5 years
      if ( NumberOfTubularAdenomasLTE10mm > 4 and NumberOfTubularAdenomasLTE10mm < 11 ) then 3.0 else 10.0, // 3 years
      if AnyAdenomaGTE10mm = true then 3.0 else 10.0,                                                       // 3 years
      if AnyPolypWithVillousOrTubulovillousHistology = true then 3.0  else 10.0,                             // 3 years
      if AnyAdenomaWithHighGradeDysplasia = true then 3.0 else 10.0 ,                                       // 3 years
      if NumberOfAdenomas > 10 then 1.0 else 10.0,                                                          // 1 year
      if AnyAdenomaGTE20mmAndPiecemealResection = true then 0.5 else 10.0                                   // 1/2 year
    }

define NextColonoscopyIntervalUpperBound:
    {
      if ( NumberOfTubularAdenomasLTE10mm > 0 and NumberOfTubularAdenomasLTE10mm < 3 ) then 10.0 else 10.0, // 7 - 10 years
      if ( NumberOfTubularAdenomasLTE10mm > 2 and NumberOfTubularAdenomasLTE10mm < 5 ) then 5.0 else 10.0,  // 3-5 years
      if ( NumberOfTubularAdenomasLTE10mm > 4 and NumberOfTubularAdenomasLTE10mm < 11 ) then 3.0 else 10.0, // 3 years
      if AnyAdenomaGTE10mm = true then 3.0 else 10.0,                                                       // 3 years
      if AnyPolypWithVillousOrTubulovillousHistology = true then 3.0  else 10.0,                             // 3 years
      if AnyAdenomaWithHighGradeDysplasia = true then 3.0 else 10.0 ,                                       // 3 years
      if NumberOfAdenomas > 10 then 1.0 else 10.0,                                                          // 1 year
      if AnyAdenomaGTE20mmAndPiecemealResection = true then 0.5 else 10.0                                   // 1/2 year
    }

define NextColonoscopyInterval: 
  {
    Min(NextColonoscopyIntervalLowerBound),
    Min(NextColonoscopyIntervalUpperBound)
  }

define NextColonoscopyMin:
    Min(NextColonoscopyIntervalLowerBound)

define NextColonoscopyMax:
    Min(NextColonoscopyIntervalUpperBound)
