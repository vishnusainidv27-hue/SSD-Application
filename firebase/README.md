# Firebase Configuration

Shared Firebase project config for SSD Farm (Spark/free plan — see Requirements §2.4).

1. Create the Firebase project at https://console.firebase.google.com (free Spark plan).
2. Register each app (Admin, Customer, Delivery Boy — Android + iOS each) inside that
   one Firebase project.
3. Download the generated config files and place them (these are git-ignored, never commit them):
   - `google-services.json` → into each app's `android/app/` folder
   - `GoogleService-Info.plist` → into each app's `ios/Runner/` folder
4. Deploy rules from this folder with the Firebase CLI:
   ```
   npm install -g firebase-tools
   firebase login
   firebase deploy --only firestore:rules,storage:rules --project <your-project-id>
   ```
