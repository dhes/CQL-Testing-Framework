const fs = require('fs-extra');
const path = require('path');
const cql = require('cql-execution');
const fhir = require('cql-exec-fhir');
const {expect} = require('chai');
const hooksExporter = require('./exporters/hooks');
const postmanExporter = require('./exporters/postman');

function buildTestSuite(testCases, library, codeService, fhirVersion, config) {
  const identifier = library.source.library.identifier;
  const libraryHandle = `${identifier.id}_v${identifier.version}`;
  const options = config.get('options');
  let executionDateTime;
  if (options && options.date != null && options.date.length > 0) {
    executionDateTime = cql.DateTime.parse(options.date);
  }
  let dumpBundlesPath, dumpResultsPath, dumpHooksPath, dumpPostmanPath, prefetchKeys;
  if (options.dumpFiles && options.dumpFiles.enabled) {
    const dumpPath = path.join(options.dumpFiles.path, libraryHandle);
    dumpBundlesPath = path.join(dumpPath, 'bundles');
    fs.mkdirpSync(path.join(dumpBundlesPath));
    dumpResultsPath = path.join(dumpPath, 'results');
    fs.mkdirpSync(path.join(dumpResultsPath));
    dumpHooksPath = path.join(dumpPath, 'hooks-requests');
    fs.mkdirpSync(path.join(dumpHooksPath));
    // Only dump the postman collections if we have at least one hookId
    if (config.get('hook.id') !== '') {
      dumpPostmanPath = path.join(dumpPath, 'postman');
      fs.mkdirpSync(path.join(dumpPostmanPath));
    }
    prefetchKeys = hooksExporter.extractPrefetchKeys(library);
  }
  const executor = new cql.Executor(library, codeService);
  describe(libraryHandle, () => {
    let patientSource;
    before('Initialize FHIR patient source', () => {
      switch (fhirVersion) {
      case '1.0.2': patientSource = fhir.PatientSource.FHIRv102(); break;
      case '3.0.0': patientSource = fhir.PatientSource.FHIRv300(); break;
      case '4.0.0': patientSource = fhir.PatientSource.FHIRv400(); break;
      case '4.0.1': patientSource = fhir.PatientSource.FHIRv401(); break;
      }
      if (patientSource == null) {
        expect.fail('Failed to initialize FHIR patient source.  Only FHIR 1.0.2, 3.0.0, 4.0.0, and 4.0.1 are supported.');
      }
    });

    before('Download value set definitions from VSAC if necessary', function(done) {
      this.timeout(30000);
      let user, pass, key;
      let ensureValueSets; //we're going to use a different function based on the existence of the API Key option
      //NOTE: As of Jan 1 2021 VSAC will no longer accept accept username and password. Please use
      //    ensureValueSetsInLibraryWithAPIKey() instead.
      if (options.vsac && options.vsac.user && options.vsac.password) {
        user = options.vsac.user ? options.vsac.user : null;
        pass = options.vsac.password ? options.vsac.password : null;
        ensureValueSets = codeService.ensureValueSetsInLibrary(library,true,user,pass);
      } else {
        key = options.vsac.apikey ? options.vsac.apikey : null;
        ensureValueSets = codeService.ensureValueSetsInLibraryWithAPIKey(library,true,key);
      }

      ensureValueSets.then(() => done())
        .catch((err) => {
          if (err instanceof Error) {
            done(err);
          } else if (err && err.indexOf('UMLS_USER_NAME') != -1) {
            const message = 'Failed to download value sets. Please ensure VSAC user and password '
              + 'is specified via one of the appropriate mechanisms, either:\n'
              + '- configuration: options.vsac.user & options.vsac.password\n'
              + '- environment variables: UMLS_USER_NAME & UMLS_PASSWORD\n'
              + '- arguments (commandline only): --vsac-user & --vsac-password';
            done(new Error(message));
          } else if(err && err.indexOf('UMLS_API_KEY') != -1) {
            const message = 'Failed to download value sets. Please ensure VSAC API Key '
              + 'is specified via one of the appropriate mechanisms, either:\n'
              + '- configuration: options.vsac.apikey\n'
              + '- environment variables: UMLS_API_KEY\n'
              + '- arguments (commandline only): --vsac-apikey\n';
            done(new Error(message));
          } else {
            done(new Error(err));
          }
        });
    });

    let postmanCollection;
    if (dumpPostmanPath) {
      before('Initialize Postman Collection', () => {
        postmanCollection = postmanExporter.initPostmanCollection(libraryHandle);
      });

      after('Dump Postman Collection', () => {
        const filePath = path.join(dumpPostmanPath, `${libraryHandle.replace(/[\s./\\]/g, '_')}.postman_collection.json`);
        fs.writeFileSync(filePath, JSON.stringify(postmanCollection, null, 2), 'utf8');
      });
    }

    afterEach('Reset the patient source', () => patientSource.reset());

    for (const testCase of testCases) {
      const testFunc = testCase.skip ? it.skip : testCase.only ? it.only : it;
      testFunc(testCase.name, () => {
        const dumpFileName = `${testCase.name.replace(/[\s/\\]/g, '_')}.json`;
        if (dumpBundlesPath) {
          const filePath = path.join(dumpBundlesPath, dumpFileName);
          fs.writeFileSync(filePath, JSON.stringify(testCase.bundle, null, 2), 'utf8');
        }
        if (dumpHooksPath || dumpPostmanPath) {
          const hooksRequest = hooksExporter.createHooksRequest(testCase.bundle, prefetchKeys);
          if (dumpHooksPath) {
            const filePath = path.join(dumpHooksPath, dumpFileName);
            fs.writeFileSync(filePath, JSON.stringify(hooksRequest, null, 2), 'utf8');
          }
          if (dumpPostmanPath) {
            postmanExporter.addHooksRequest(testCase, hooksRequest, config.get('hook'), postmanCollection);
          }
        }
        patientSource.loadBundles([testCase.bundle]);
        const results = executor.exec(patientSource, executionDateTime);
        if (dumpResultsPath) {
          const filePath = path.join(dumpResultsPath, dumpFileName);
          fs.writeFileSync(filePath, JSON.stringify(results, null, 2), 'utf8');
        }
        const patientId = testCase.bundle.entry[0].resource.id;
        expect(results.patientResults[patientId]).to.exist;
        for (const expr of Object.keys(testCase.expected)) {
          checkResult(expr, results.patientResults[patientId][expr], testCase.expected[expr]);
        }
      });
    }
  });
}

function checkResult(expr, actual, expected) {
  if (/^\$should/.test(expected)) {
    let expectedString = String(expected);
    const message = `${expr} ${expectedString.slice(1)}`;
    if (/^\$should exist/.test(expectedString)) {
      expect(actual, message).to.exist;
    } else if (/^\$should have length (\d+)/.test(expectedString)) {
      let expectedLength = Number(expectedString.match(/^\$should have length (\d+)/)[1]);
      expect(actual, message).to.have.lengthOf(expectedLength);
    } else { // Anything else is not supported
      throw new Error(`Unsupported $should method: ${message}`);
    }
  } else {
    const simpleResult = simplifyResult(actual);
    const message = `${expr}=<${simpleResult}>`;
    expect(simpleResult, message).to.eql(expected);
  }
}

function simplifyResult(result) {
  if (result == null) {
    return result;
  } else if (Array.isArray(result)) {
    return result.map(r => simplifyResult(r));
  } else if (result instanceof cql.DateTime || result.constructor.name === 'DateTime') {
    return result.toString();
  } else if (result instanceof cql.Date || result.constructor.name === 'Date') {
    return result.toString();
  } else if (result instanceof cql.Quantity || result.constructor.name === 'Quantity') {
    let result2 = {};
    for (const key of Object.keys(result)) {
      result2[key] = simplifyResult(result[key]);
    }
    return result2;
  } else if (result != null && typeof result === 'object') {
    for (const key of Object.keys(result)) {
      result[key] = simplifyResult(result[key]);
    }
  }
  return result;
}

module.exports = buildTestSuite;
