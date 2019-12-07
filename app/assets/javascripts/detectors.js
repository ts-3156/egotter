'use strict';

var Detectors = {};

Detectors.secretMode = function (detected) {
  if ('storage' in navigator && 'estimate' in navigator.storage) {
    navigator.storage.estimate().then(function (estimate) {
      var usage = estimate.usage;
      var quota = estimate.quota;

      if (quota < 120000000) {
        console.log('Incognito');
        ga('send', {
          hitType: 'event',
          eventCategory: 'SecretMode detected',
          eventAction: 'detected',
          eventLabel: 'detected'
        });
        detected();
      } else {
        console.log('Not Incognito')
      }
    });
  } else {
    console.log('Can not detect');
  }
};

Detectors.adBlocker = function (detected) {
  if (document.getElementById('poinpgwawoiwoignsdoa')) {
    console.log('Blocking Ads: No');
  } else {
    console.log('Blocking Ads: Yes');
    ga('send', {
      hitType: 'event',
      eventCategory: 'AdBlocker detected',
      eventAction: 'detected',
      eventLabel: 'detected'
    });
    detected();
  }
};
