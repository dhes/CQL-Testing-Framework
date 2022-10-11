# Computing Colonoscopy

![Knowledge Levels](/images/KnowledgeLevels.png)

This project converts Semi-Structure (level 2) Colonoscopy follow-up guidelines to a Structured (Level 3) artifact. In this testing environment a test file reside at test/yaml/colon_polyp_r401/tests/Bundle-example-cpBundle.yaml. 

The test/yaml/colon_polyp_r401/cql/CDS_Connect_Commons_for_FHIRv401.cql CQL file applies this CQL to the test file. Current status: This is the one an only test that has been written, and it does pass. This gives us ONE sample of structures colonoscopy polyp data that runs against a sample of colonoscopy follow-up CQL. 

The CDS-hooks repository discussed how this might be converted to a Level 4 (executable) installation. 