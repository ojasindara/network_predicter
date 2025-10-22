# xgb_signal_prediction_firebase.py
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score
from xgboost import XGBRegressor
import joblib
import firebase_admin
from firebase_admin import credentials, firestore

# ====== CONFIG ======
CSV_PATH = "network_logs_test.csv"   # <-- change to your CSV path
MODEL_OUT = "xgb_signal_strength_model.pkl"
RANDOM_STATE = 42
TARGET = "download_mbps"             # change to "upload_mbps" if you prefer
# ====================


# ---------------- Firebase Setup ----------------
# Replace with the path to your Firebase service account JSON
#cred = credentials.Certificate("serviceAccountKey.json")
#firebase_admin.initialize_app(cred)

#db = firestore.client()
#collection_name = "networkLogs"

# ---------------- Fetch Data from Firestore ----------------
#docs = db.collection(collection_name).stream()
#records = []

#for doc in docs:
#    data = doc.to_dict()
    # Convert kBps to Mbps if needed (your Flutter code stores kBps)
#    download_mbps = data.get("download_kbps", 0) / 1000
#    upload_mbps = data.get("upload_kbps", 0) / 1000
#    records.append({
#        "latitude": data.get("latitude"),
#        "longitude": data.get("longitude"),
#        "signal_dbm": data.get("signal_dbm"),
#        "download_mbps": download_mbps,
#        "upload_mbps": upload_mbps
#    })

# ---------------- Load Dataset ----------------
df = pd.DataFrame(records)

if df.empty:
    raise ValueError("No data fetched from Firebase.")

# ---------------- Data Cleaning ----------------
df = df.dropna(subset=["signal_dbm", "latitude", "longitude", "download_mbps", "upload_mbps"])

# ---------------- Feature Selection ----------------
features = ["signal_dbm", "latitude", "longitude"]
target = "download_mbps"  # Change to 'upload_mbps' if predicting upload speed

X = df[features]
y = df[target]

# ---------------- Split into Train/Test ----------------
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# ---------------- Train Model ----------------
model = XGBRegressor(
    n_estimators=250,
    learning_rate=0.08,
    max_depth=6,
    subsample=0.9,
    colsample_bytree=0.9,
    random_state=42,
    objective='reg:squarederror'
)
model.fit(X_train, y_train)

# ---------------- Evaluate Model ----------------
y_pred = model.predict(X_test)
mse = mean_squared_error(y_test, y_pred)
r2 = r2_score(y_test, y_pred)

print(f"✅ Model trained successfully")
print(f"📉 Mean Squared Error: {mse:.4f}")
print(f"📈 R² Score: {r2:.4f}")

# ---------------- Save Model ----------------
joblib.dump(model, "xgb_signal_strength_model.pkl")
print("💾 Model saved as 'xgb_signal_strength_model.pkl'")

# ---------------- Example Prediction ----------------
example = pd.DataFrame({
    "signal_dbm": [-80],
    "latitude": [6.5244],
    "longitude": [3.3792]
})
pred_speed = model.predict(example)[0]
print(f"🌐 Predicted Download Speed: {pred_speed:.2f} Mbps")
