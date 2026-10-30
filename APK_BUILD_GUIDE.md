# APK বানানোর সম্পূর্ণ গাইড

## ধাপ ১: প্রজেক্ট সেটআপ (যদি আগে না করে থাকো)
```
flutter create tuition_tracker
```
এরপর এই zip এর `lib/`, `pubspec.yaml`, `assets/` — এই তিনটা তোমার তৈরি করা `tuition_tracker` folder এ replace/copy করে দাও।

## ধাপ ২: Dependencies ইনস্টল
```
flutter pub get
```

## ধাপ ৩: App icon জেনারেট করো
```
dart run flutter_launcher_icons
```
এটা Android এর সব mipmap সাইজ + iOS AppIcon.appiconset auto তৈরি করে দেবে।

## ধাপ ৪: Splash screen জেনারেট করো
```
dart run flutter_native_splash:create
```
এটা app চালু হওয়ার সময় সবুজ background এ তোমার icon দেখাবে।

## ধাপ ৫: App এর নাম বদলাও
`android/app/src/main/AndroidManifest.xml` ফাইল খুলে এই লাইনটা খুঁজে বের করো:
```xml
android:label="tuition_tracker"
```
বদলে দাও:
```xml
android:label="টিউশন ট্র্যাকার"
```

## ধাপ ৬: Package name (applicationId) বদলাও
`android/app/build.gradle` (অথবা `build.gradle.kts`) ফাইলে খুঁজো:
```
applicationId "com.example.tuition_tracker"
```
বদলে দাও (নিজের মতো ইউনিক নাম দাও, যেমন):
```
applicationId "com.sifat.tuitiontracker"
```
> এটা বদলানো জরুরি — `com.example.*` দিয়ে Play Store এ আপলোড করা যায় না, আর এমনিতেও এটা তোমার নিজের identifier হওয়া উচিত।
>
> ✅ এই প্রজেক্টে করা হয়ে গেছে (`com.sifat.tuitiontracker`)। Package name বদলালে Firebase এ নতুন Android app যোগ করতে হয় — `flutterfire configure` চালালে `google-services.json` আর `lib/firebase_options.dart` নিজে থেকেই আপডেট হয়।

## ধাপ ৭: Release APK বানাও
```
flutter build apk --release
```
বিল্ড শেষ হলে APK পাবে এখানে:
```
build/app/outputs/flutter-apk/app-release.apk
```
এই ফাইলটা সরাসরি ফোনে কপি করে ইনস্টল করা যাবে (নিজের ব্যবহারের জন্যে, Play Store signing key ছাড়াই ডিফল্ট debug key দিয়ে সাইন হবে — personal install এ কোনো সমস্যা নেই)।

## ধাপ ৮ (ঐচ্ছিক): ছোট APK size চাইলে
```
flutter build apk --release --split-per-abi
```
এতে প্রতিটা CPU architecture এর জন্যে আলাদা ছোট APK তৈরি হবে (২০-৩০ MB এর জায়গায় ৭-১০ MB এর মতো হতে পারে)। ফোনে ইনস্টল করার সময় `app-arm64-v8a-release.apk` টাই বেশিরভাগ আধুনিক ফোনের জন্যে লাগবে।

## সমস্যা হলে
- **"applicationId not found" error** → নতুন Flutter version এ `build.gradle.kts` (Kotlin DSL) ব্যবহার হয়, সেখানে সিনট্যাক্স একটু আলাদা: `applicationId = "com.sifat.tuitiontracker"` (= চিহ্ন সহ)
- **Icon আপডেট হচ্ছে না** → `flutter clean` করে আবার `flutter pub get` আর `flutter build apk --release` চালাও
- **build_runner সংক্রান্ত কোনো error** → এই প্রজেক্টে build_runner ব্যবহারই হয়নি, তাই এই error আসার কথা না; আসলে বুঝবে কোনো ভুল package বসে গেছে
