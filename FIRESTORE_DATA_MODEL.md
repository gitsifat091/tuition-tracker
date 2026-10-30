# Firestore ডেটা মডেল — টিউশন প্ল্যাটফর্ম (Teacher + Student)

## ১. Collections (সব top-level, flat structure)

### `users/{uid}`
Firebase Auth এর uid দিয়েই document id। Login করার পর role অনুযায়ী app কোন screen দেখাবে সেটা এখান থেকে ঠিক হয়।

| Field | Type | বিবরণ |
|---|---|---|
| role | string | `'teacher'` অথবা `'student'` |
| name | string | |
| phone | string | login এ ব্যবহৃত নম্বর |
| createdAt | timestamp | |

### `students/{studentId}`
আগের Hive `Student` model এর সব field + ২টা নতুন field (invite system এর জন্যে)।

| Field | Type | বিবরণ |
|---|---|---|
| tutorId | string | কোন teacher এর ছাত্র (আগে single-user ছিল বলে এই field ছিল না) |
| name, className, subject, parentPhone, monthlyFee | — | আগের মতোই |
| classDays, classTime | — | আগের মতোই |
| **inviteCode** | string | ৬ ডিজিটের কোড, teacher student add করলে auto generate হবে |
| **linkedUserId** | string? | student নিজে sign up করার পর তার `users/{uid}` এখানে বসবে; sign up না করলে null |
| joinDate, lastModified | — | আগের মতোই |

### `attendance/{recordId}`
| Field | Type |
|---|---|
| tutorId | string |
| studentId | string |
| date | timestamp |
| status | `'present'` \| `'absent'` |

**Document id নির্ধারিত (deterministic):** `{studentId}_{yyyy-MM-dd}`।
একই ছাত্রের একই দিনের রেকর্ড সবসময় একই id পায়, তাই `set()` বারবার চললেও নতুন
document তৈরি হয় না। আগে random UUID ছিল বলে "উপস্থিত" বাটনে দ্রুত দুবার চাপ
পড়লে একই দিনের দুটো রেকর্ড ঢুকে যেতে পারত।
(পুরনো random-id রেকর্ড থাকলে সেগুলোও কাজ করে — app পড়ার সময় ছেঁকে নেয়।)

### `fees/{recordId}`
| Field | Type |
|---|---|
| tutorId | string |
| studentId | string |
| month | string (`"2026-08"`) |
| amount | number |
| status | `'paid'` \| `'due'` |
| paidDate | timestamp? |

**Document id নির্ধারিত (deterministic):** `{studentId}_{yyyy-MM}`।

এটাই ছিল "একই মাসের ফি ৬/৭ বার দেখাচ্ছে" বাগের মূল কারণ — আগে প্রতিবার নতুন
UUID বানানো হতো, আর fee tab খোলার সময় Firestore এর প্রথম snapshot আসার
*আগেই* "এই মাস আছে কি?" পরীক্ষা করা হতো। খালি তালিকায় উত্তর সবসময় "নেই",
তাই অ্যাপ যতবার খোলা হতো ততবার প্রতিটা মাসের নতুন একটা করে document তৈরি হতো।

এখন:
- একই (ছাত্র, মাস) = একই document id, তাই `set()` idempotent;
- প্রথম snapshot না আসা পর্যন্ত (`FeeProvider.loaded`) কোনো রেকর্ড বানানো হয় না;
- পড়ার সময় `dedupeFeeRecords()` দিয়ে প্রতি (ছাত্র, মাস) জোড়ায় একটাই রেকর্ড
  রাখা হয় — "পরিশোধিত" থাকলে সেটাকেই অগ্রাধিকার, যাতে কারো দেওয়া টাকার হিসাব
  না হারায়। ফলে পুরনো ডুপ্লিকেট থাকলেও দেখানো তালিকা আর মোট অঙ্ক ঠিক থাকে;
- ফি ট্যাবের ব্যানার থেকে পুরনো বাড়তি document গুলো একবারে মুছে ফেলা যায়।

### `exams/{examId}` (পরীক্ষার রুটিন)
| Field | Type |
|---|---|
| tutorId | string |
| studentId | string |
| subject | string (`"গণিত"`) |
| examName | string (`"অর্ধবার্ষিক পরীক্ষা"`, ঐচ্ছিক) |
| date | timestamp (দিন-মাত্র) |
| startTime | string? (`"10:00 AM"`) |
| endTime | string? (`"12:00 PM"`) |
| syllabus | string (ঐচ্ছিক) |
| createdAt | timestamp |

একটা পরীক্ষার প্রতিটা বিষয় আলাদা document। "অর্ধবার্ষিক পরীক্ষা" এর গণিত আর
ইংরেজি — দুটো রেকর্ড, দুটোরই `examName` এক। এতে প্রতিটা বিষয়ের নিজের তারিখ ও
সময় থাকতে পারে। Document id random UUID — এখানে (ছাত্র, মাস) এর মতো কোনো
স্বাভাবিক unique key নেই, একই দিনে দুটো পরীক্ষা থাকা সম্ভব। দুবার সেভ হওয়া
ঠেকাতে ফর্মের বাটনে `saving` guard আছে।

শিক্ষক add/edit/delete করে, ছাত্র শুধু পড়ে।

### `notes/{noteId}` (CW/HW/মার্কস)
| Field | Type |
|---|---|
| tutorId | string |
| studentId | string |
| date | timestamp |
| topic | string (CW) |
| homework | string |
| marks, outOf | number? |
| remarks | string |

### `syllabus/{itemId}`
| Field | Type |
|---|---|
| tutorId | string |
| studentId | string |
| title | string |
| isDone | bool |
| materialNote | string |
| createdAt | timestamp |

---

## ২. সম্পর্ক (Relationships)

```
users (teacher) ──owns──> students ──has──> attendance
                                    ├──has──> fees
                                    ├──has──> notes
                                    └──has──> syllabus

users (student) ──linkedUserId──> students (একটামাত্র profile এর সাথে link)
```

## ৩. Invite Code Flow

1. Teacher app এ "নতুন ছাত্র যোগ করুন" করলে `students` doc তৈরি হবে + এলোমেলো ৬-ডিজিট `inviteCode` (যেমন `482913`)।
2. Teacher এই কোড ছাত্রকে WhatsApp/SMS এ পাঠাবে (এখনকার fee reminder button এর মতোই একটা "invite পাঠান" বাটন থাকবে)।
3. Student app খুলে "আমি ছাত্র" বেছে sign up করবে, তারপর কোড লিখবে।
4. App সেই কোড দিয়ে `students` collection এ query করে matching doc খুঁজবে, পেলে সেই doc এর `linkedUserId` তে student এর নতুন `uid` বসিয়ে দেবে।
5. এরপর থেকে student login করলে তার `linkedUserId` দিয়ে নিজের profile আর সব data খুঁজে পাবে।

## ৪. Security Rules (concept, deploy করার সময় চূড়ান্ত করবো)

```
// students: teacher নিজের সব ছাত্র পড়তে/লিখতে পারবে,
// student শুধু নিজের profile পড়তে পারবে (লিখতে পারবে না)
match /students/{studentId} {
  allow read: if request.auth.uid == resource.data.tutorId
              || request.auth.uid == resource.data.linkedUserId;
  allow write: if request.auth.uid == resource.data.tutorId;
}

// attendance, fees, notes, syllabus — একই প্যাটার্ন:
// teacher পড়তে/লিখতে পারবে, student শুধু নিজেরটা পড়তে পারবে
match /attendance/{recordId} {
  allow read: if request.auth.uid == resource.data.tutorId
              || request.auth.uid == get(/databases/$(database)/documents/students/$(resource.data.studentId)).data.linkedUserId;
  allow write: if request.auth.uid == resource.data.tutorId;
}
// fees, notes, syllabus এও একই rule বসবে
```

**মূলনীতি:** Student কোনো data কখনো *লিখতে* পারবে না (attendance/fee/homework সবই teacher-controlled), শুধু *পড়তে* পারবে — নিজেরটাই।

## ৫. Hive → Firestore মাইগ্রেশন নোট

- পুরনো Hive `Student.toJson()`/`fromJson()` structure প্রায় হুবহু থাকবে, শুধু `tutorId`, `inviteCode`, `linkedUserId` নতুন যোগ হবে
- `id` field UUID ভিত্তিক ছিল, Firestore এ document id হিসেবেই সেটা ব্যবহার করা যাবে (একই approach, পরিবর্তন লাগবে না)
- Provider ক্লাসগুলোর ভিতরের Hive Box কল গুলো Firestore query দিয়ে replace হবে, কিন্তু বাইরের interface (`addStudent`, `updateStudent` ইত্যাদি) একই থাকবে — UI কোড প্রায় অপরিবর্তিত থাকবে
