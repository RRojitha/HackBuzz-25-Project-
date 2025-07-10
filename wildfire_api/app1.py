from flask import Flask, request, jsonify
from tensorflow.keras.models import load_model
import joblib
import numpy as np
import requests

# Load the trained model and scaler
model = load_model("landslide_model_optimized.h5")
scaler = joblib.load("scaler.pkl")

# Initialize Flask app
app = Flask(__name__)

# Function to get real-time rainfall data from OpenWeatherMap API
def get_rainfall(lat, lon, api_key):
    url = f"http://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={api_key}&units=metric"
    response = requests.get(url).json()
    return response.get("rain", {}).get("1h", 0)  # Default to 0 if missing

# Function to estimate soil saturation based on rainfall
def estimate_soil_saturation(rainfall_mm):
    return min(rainfall_mm / 100, 1)  # Normalize to 0-1 range

# Function to get real-time earthquake data from USGS API
def get_earthquake_activity(min_magnitude=4.0):
    url = "https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&minmagnitude={}&starttime=now-1day".format(min_magnitude)
    response = requests.get(url).json()

    for quake in response["features"]:
        if "erode" in quake["properties"]["place"].lower():
            return 1  # Earthquake detected near Erode
    return 0  # No significant earthquake

# API endpoint to predict landslide risk
@app.route('/predict', methods=['POST'])
def predict_landslide():
    data = request.get_json()  # Get coordinates from Flutter app
    lat = data['lat']
    lon = data['lon']
    
    # Get real-time values
    rainfall_mm = get_rainfall(lat, lon, "882c7ba9bc4358298d4e08b801b60416")
    soil_saturation = estimate_soil_saturation(rainfall_mm)
    slope_angle = 30  # Static value based on Erode's geography or can be dynamic
    earthquake_activity = get_earthquake_activity()

    # Normalize real-time inputs using the trained scaler
    real_time_data = scaler.transform([[rainfall_mm, slope_angle, soil_saturation, earthquake_activity]])

    # Predict landslide risk
    prediction = model.predict(real_time_data)
    risk = "High Risk" if prediction[0][0] > 0.6 else "Low Risk"

    # Print the result in the console (for debugging purposes)
    print(f"Prediction: Risk = {risk}, Rainfall = {rainfall_mm}, Soil Saturation = {soil_saturation}, Earthquake Activity = {earthquake_activity}")

    # Return the result as JSON
    return jsonify({
        'rainfall': rainfall_mm,
        'soil_saturation': soil_saturation,
        'slope_angle': slope_angle,
        'earthquake_activity': earthquake_activity,
        'risk': risk
    })

if __name__ == '__main__':
    app.run(debug=True)
