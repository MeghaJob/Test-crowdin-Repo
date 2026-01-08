const axios = require('axios').default;
const AdmZip = require("adm-zip");
const shell = require('shelljs');

/** PROCESS VARIABLES */
const [, , CROWDIN_PROJECT_ID, CROWDIN_TOKEN] = process.argv;
let checkBuilStatusInterval;
const BASE_URL = `https://api.crowdin.com/api/v2/projects/${CROWDIN_PROJECT_ID}/translations/builds`;
const HEADERS = { 'Authorization': `Bearer ${CROWDIN_TOKEN}` };

const checkBuildStatus = (buildId) => {
  console.log("Checking Build Status...");
  return axios.get(`${BASE_URL}/${buildId}`,{
    headers: HEADERS,
  }).then(response=> {
    if(response.data && response.data.data) {
      const status = response.data.data.status;
      console.log("Status:: ", status);
      if(status == "inProgress") {
        return status;
      } else if(status == "finished") {
        clearInterval(checkBuilStatusInterval);
        getDownloadURL(buildId);
      }
      return status;
    }
  }).catch(err=> {
    console.log(err);
  })
}

const buildTranslations = () => {
  console.log("Building Translations...");

  return axios.post(BASE_URL, {}, {
    headers: HEADERS,
  }).then(response=> {
    if(response.data && response.data.data) {
      let buildId = response.data.data.id;
      // The build process usually takes more than a minute due to large number of keys. So, we are only proceeding
      // to the next step if this build finishes. Until then, we check the status every 10 seconds
      checkBuilStatusInterval = setInterval(checkBuildStatus, 10000, buildId);
    }
  }).catch(err=> {
    console.log(err);
  })
}

const getDownloadURL = (buildId) => {
  console.log("Fetching zip download url...");
  let zipURL = "";

  axios.get(`${BASE_URL}/${buildId}/download`, {
    headers: HEADERS
  }).then(response => {
    if(response && response.data) {
      zipURL = response.data.data.url;
      downloadTranslations(zipURL);
    }
  }).catch(err=> {
    console.log(err);
  })
}

const downloadTranslations = (zipURL) => {
  console.log("Downloading Translations...");
  axios.get(zipURL, { responseType: 'arraybuffer' }).then(res => {
    console.log('Zip download status ', res.status);
    var zipFile = new AdmZip(res.data);
    zipFile.extractAllTo('./tmp');
    shell.exec(`chmod +x yaml_merge_portal.sh && ./yaml_merge_portal.sh`);
    console.log("Removing package lock json file");
    shell.exec('rm -rf tmp && cd js && [ -f "package-lock.json" ] && rm package-lock.json && cd ..')
  }).catch(err=> {
    console.log(err);
  });
}

buildTranslations();

