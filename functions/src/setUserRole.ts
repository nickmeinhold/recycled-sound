import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const VALID_ROLES = ["donor", "recipient", "audiologist", "admin"] as const;
type Role = (typeof VALID_ROLES)[number];

/**
 * Sets the user's role as a Firebase Auth custom claim.
 *
 * Custom claims propagate to the client's ID token, enabling role-based
 * route guards in Flutter and Firestore security rules.
 *
 * Only admins can assign the 'admin' or 'audiologist' roles to other users.
 * Users can self-assign 'donor' or 'recipient' during signup.
 */
export const setUserRole = functions.https.onCall(
  {region: "australia-southeast1"},
  async (request) => {
    const {targetUid, role} = request.data;
    const callerUid = request.auth?.uid;

    if (!callerUid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be signed in"
      );
    }

    if (!targetUid || !role || !VALID_ROLES.includes(role as Role)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `role must be one of: ${VALID_ROLES.join(", ")}`
      );
    }

    // Elevated roles require admin privileges — no exceptions
    if (role === "admin" || role === "audiologist") {
      const callerRecord = await admin.auth().getUser(callerUid);
      const callerRole = callerRecord.customClaims?.role;
      if (callerRole !== "admin") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only admins can assign audiologist or admin roles. " +
            "Bootstrap the first admin via Firebase Console or Admin SDK."
        );
      }
    }

    // Self-assignment: only donor/recipient allowed
    if (callerUid === targetUid && (role === "admin" || role === "audiologist")) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Cannot self-assign elevated roles"
      );
    }

    // Set custom claim
    await admin.auth().setCustomUserClaims(targetUid, {role});

    // Mirror role to Firestore user doc for queries
    await admin.firestore().collection("users").doc(targetUid).set(
      {role, updatedAt: admin.firestore.FieldValue.serverTimestamp()},
      {merge: true}
    );

    return {success: true, role};
  }
);
