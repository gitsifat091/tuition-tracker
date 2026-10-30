# Firebase সেটআপ গাইড

## ধাপ ১: Firebase প্রজেক্ট বানাও
1. https://console.firebase.google.com এ যাও, Google account দিয়ে লগইন করো
2. "Add project" → নাম দাও (যেমন `tuition-tracker`) → পরের ধাপগুলোতে ডিফল্ট রেখে "Create project"

## ধাপ ২: Authentication চালু করো
1. বাম পাশের মেনু থেকে **Build → Authentication** এ যাও
2. "Get started" চাপো
3. **Email/Password** provider এ ক্লিক করে **Enable** করো, Save করো

## ধাপ ৩: Firestore Database বানাও
1. বাম মেনু থেকে **Build → Firestore Database** এ যাও
2. "Create database" চাপো
3. Location হিসেবে কাছাকাছি একটা region বেছে নাও (যেমন `asia-south1` — Mumbai)
4. **Start in test mode** বেছে নাও (আমরা পরে security rules বসাবো, এখন test mode এ development সহজ হবে)

## ধাপ ৪: FlutterFire CLI ইনস্টল করো
টার্মিনালে:
```
dart pub global activate flutterfire_cli
```
যদি Firebase CLI আগে থেকে না থাকে:
```
npm install -g firebase-tools
firebase login
```

## ধাপ ৫: প্রজেক্টে Firebase configure করো
তোমার `tuition_tracker` ফোল্ডারে গিয়ে:
```
flutterfire configure
```
- এটা তোমাকে Firebase account থেকে প্রজেক্ট বেছে নিতে বলবে (ধাপ ১ এ বানানো `tuition-tracker`)
- কোন platform চাও জিজ্ঞেস করবে — Android আর iOS দুটোই বেছে নাও (space দিয়ে select, enter দিয়ে confirm)
- এই কমান্ড শেষ হলে `lib/firebase_options.dart` ফাইলটা automatically সঠিক keys দিয়ে replace হয়ে যাবে (এই zip এ যে placeholder ফাইল আছে সেটা তখন আর দরকার নেই)

## ধাপ ৬: Android minSdkVersion বাড়াও
`android/app/build.gradle` (বা `build.gradle.kts`) ফাইলে খুঁজো:
```
minSdkVersion 21
```
বদলে দাও:
```
minSdkVersion 23
```
(Firebase Auth এর জন্যে এটা লাগে; না বদলালে build error দেবে)

## ধাপ ৭: চালাও
```
flutter pub get
flutter run
```

---

## এখন যা কাজ করবে
- Login/Signup screen — "শিক্ষক" বা "ছাত্র/ছাত্রী" বেছে অ্যাকাউন্ট বানানো যাবে
- Teacher signup করলে সরাসরি আগের HomeScreen এ চলে যাবে (attendance/fee/syllabus সব, তবে **এখনো local Hive data** — Firestore migration পরের ধাপে হবে)
- Student signup এর জন্যে invite code লাগবে — কিন্তু এখনো কোনো student profile Firestore এ তৈরি হয় না (সেটাও Hive migration এর পরে সম্ভব হবে), তাই আপাতত student signup করলে "কোড ভুল" error দেখাবে — এটাই স্বাভাবিক, চিন্তার কিছু নেই
- পরের ধাপে (data migration) আমরা teacher এর student-add flow টা Firestore এ নিয়ে যাবো, তখন থেকে invite code আসলেই কাজ করবে

## সমস্যা হলে
- **"MissingPluginException"** → `flutter clean` করে `flutter pub get` আবার চালাও, তারপর app পুরোপুরি বন্ধ করে আবার `flutter run`
- **"No Firebase App '[DEFAULT]' has been created"** → `flutterfire configure` ঠিকমতো চলেনি, আবার চালাও
- **Gradle build error (minSdkVersion related)** → ধাপ ৬ ঠিকমতো করা হয়েছে কিনা চেক করো
