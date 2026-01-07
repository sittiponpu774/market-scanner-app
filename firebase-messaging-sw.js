importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCb0Nt9CpM_BtgFfh9_rtAdWoVsYB_nO0Q",
  authDomain: "predictionapp-3c436.firebaseapp.com",
  projectId: "predictionapp-3c436",
  storageBucket: "predictionapp-3c436.firebasestorage.app",
  messagingSenderId: "786358717490",
  appId: "1:786358717490:web:20b8461f446c927e60802b"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Received background message:', payload);
  
  const notificationTitle = payload.notification?.title || 'Signal Alert';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
