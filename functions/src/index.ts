import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// 共通参照ヘルパー
const ticketRef = (uid: string) =>
  db.collection("users").doc(uid).collection("tickets").doc(uid);

// 🔹 タイマー開始
export const startTimer = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Auth Error");

  const uid = request.auth.uid;
  const ref = ticketRef(uid);
  const snap = await ref.get();

  // 初回ユーザーならデフォルト作成
  if (!snap.exists) {
    await ref.set({
      remaining_seconds: 100,
      is_active: false,
      last_started_at: null,
    });
  }

  await ref.update({
    is_active: true,
    last_started_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {status: "started"};
});

// 🔹 タイマー停止 & 残り時間更新
export const stopTimer = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Auth Error");

  const uid = request.auth.uid;
  const ref = ticketRef(uid);
  const snap = await ref.get();
  const data = snap.data();

  if (!data || !data.is_active || !data.last_started_at) {
    return {remaining_seconds: data?.remaining_seconds ?? 0};
  }

  const lastStarted = data.last_started_at.toDate().getTime();
  const elapsed = Math.floor((Date.now() - lastStarted) / 1000);

  let remaining = (data.remaining_seconds || 0) - elapsed;
  if (remaining < 0) remaining = 0;

  await ref.update({
    remaining_seconds: remaining,
    is_active: false,
    last_started_at: null,
  });

  return {remaining_seconds: remaining};
});

// 🔹 残り時間取得（表示用）
export const getRemainingTime = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

  const uid = request.auth.uid;
  const snap = await ticketRef(uid).get();

  return {
    remaining_seconds: snap.data()?.remaining_seconds ?? 0,
  };
});
