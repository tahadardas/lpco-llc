/* global importScripts, firebase */

importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js');

const firebaseConfig = self.firebaseWebConfig || {
  apiKey: 'REPLACE_WITH_WEB_API_KEY',
  appId: '1:000000000000:web:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'REPLACE_WITH_PROJECT_ID',
};

const isConfigured =
  firebaseConfig &&
  typeof firebaseConfig.apiKey === 'string' &&
  !firebaseConfig.apiKey.startsWith('REPLACE_WITH_') &&
  typeof firebaseConfig.projectId === 'string' &&
  !firebaseConfig.projectId.startsWith('REPLACE_WITH_') &&
  firebaseConfig.messagingSenderId !== '000000000000';

if (isConfigured) {
  firebase.initializeApp(firebaseConfig);
  firebase.messaging();
}
