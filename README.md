# DiamondCarApplication

# npm run dev 
# to run stripe + node + dlutter

# stripe listen --forward-to localhost:8000/stripe/webhook



# DiamondCar persistent authentication

## Files to replace/add

Copy each file into the matching `Server` or `Client` path in your project.

Your existing `LoginPage` does not need a navigation change: `AuthApi.login()`
still returns the user map, but now saves the tokens before returning it.

## 1. Install the server dependency

From `DiamondCarApplication/Server`:

```bash
npm install jsonwebtoken
```

## 2. Generate secrets

Run this command twice from Git Bash:

```bash
node -e "console.log(require('node:crypto').randomBytes(64).toString('hex'))"
```

Add the two different results to `Server/.env`:

```env
JWT_ACCESS_SECRET=first_generated_value
JWT_REFRESH_SECRET=second_generated_value
```

Never add `Server/.env` to Git.

## 3. Add Logout to your account page

Your current `LoginPage` already calls `AuthApi.login()`, so it needs no code
change. The updated API stores the returned session before navigation.

In `Client/lib/renter/navbar_pages/account/account.dart`, import the helper:

```dart
import '../../../authentication/logout_helper.dart';
```

Replace the current `logOut()` method with:

```dart
Future<void> logOut() async {
  try {
    await logoutAndReturnToWelcome(context);
  } catch (error) {
    debugPrint('Error logging out: $error');
    if (mounted) {
      _showMessage('Could not log out. Please try again.', isError: true);
    }
  }
}
```

## 4. Important: Change Password and Change Username

Any server method that checks the current password must explicitly select the
password and use the shared verifier:

```js
import {
  hashPassword,
  verifyPassword,
} from "../../utils/password.js";

const user = await User.findById(userId).select("+password");
const valid = await verifyPassword(currentPassword, user.password);

if (!valid) {
  return res.status(401).json({ message: "Current password is incorrect" });
}
```

When changing a password, never save it directly:

```js
user.password = await hashPassword(newPassword);
await user.save();
```

This is required because `password` is now `select: false` and existing
plain-text passwords are upgraded to bcrypt after a successful login.

## 5. Test

Fully stop and restart Node and Flutter, then:

1. Log in normally once.
2. Close the app completely.
3. Open it again; it should open the correct dashboard.
4. Tap Logout; it should return to Welcome.
5. Reopen the app; it should remain logged out.

The access token lasts 15 minutes. The rotating refresh session lasts 90 days
and is stored using Flutter Secure Storage. Users must log in again after the
refresh session expires or after logout.
