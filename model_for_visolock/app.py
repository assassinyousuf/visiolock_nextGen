"""
Flask API Server for VisioLock++ Adaptive Transmission Model
Wraps the pre-trained Random Forest classifier for real-time parameter recommendations
"""

from flask import Flask, request, jsonify
from inference import AdaptiveTransmissionModel
import logging
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Initialize the pre-trained model
try:
    model_path = os.path.join(os.path.dirname(__file__), 'adaptive_model.pkl')
    ai_model = AdaptiveTransmissionModel(model_path=model_path)
    logger.info("✓ AI Model loaded successfully")
except Exception as e:
    logger.error(f"✗ Failed to load AI model: {e}")
    ai_model = None


@app.route('/predict', methods=['POST'])
def predict():
    """
    Predict optimal transmission configuration
    
    Expected JSON input:
    {
        "file_type": "image|audio|video|text",
        "file_size_kb": float,
        "snr": float,  # Signal-to-Noise Ratio in dB
        "noise_level": float  # 0.0-1.0 normalized
    }
    
    Returns JSON:
    {
        "success": true/false,
        "encoding": "AES-128|AES-256|..."
        "coding": "RS|convolutional|turbo",
        "modulation": "16-QAM|64-QAM|..."
    }
    """
    try:
        # Validate request
        if not request.is_json:
            return jsonify({
                "success": False,
                "error": "Request must be JSON"
            }), 400
        
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['file_type', 'file_size_kb', 'snr', 'noise_level']
        if not all(field in data for field in required_fields):
            return jsonify({
                "success": False,
                "error": f"Missing required fields: {required_fields}"
            }), 400
        
        # Extract inputs
        file_type = data['file_type']
        file_size_kb = float(data['file_size_kb'])
        snr = float(data['snr'])
        noise_level = float(data['noise_level'])
        
        # Validate ranges
        if file_size_kb < 0:
            return jsonify({
                "success": False,
                "error": "file_size_kb must be non-negative"
            }), 400
        
        if not (0 <= noise_level <= 1):
            return jsonify({
                "success": False,
                "error": "noise_level must be between 0 and 1"
            }), 400
        
        # Check if model is loaded
        if ai_model is None:
            logger.warning("Model not available, returning default configuration")
            return jsonify({
                "success": True,
                "source": "fallback",
                "encoding": "AES-128",
                "coding": "RS",
                "modulation": "16-QAM",
                "note": "Using fallback configuration (model unavailable)"
            }), 200
        
        # Get prediction from model
        config = ai_model.predict_config(
            file_type=file_type,
            file_size_kb=file_size_kb,
            snr=snr,
            noise_level=noise_level
        )
        
        if config:
            return jsonify({
                "success": True,
                "source": "ai_model",
                "encoding": config['encoding'],
                "coding": config['coding'],
                "modulation": config['modulation']
            }), 200
        else:
            logger.error("Model returned None")
            return jsonify({
                "success": False,
                "error": "Model prediction failed"
            }), 500
    
    except ValueError as e:
        logger.error(f"Invalid input: {e}")
        return jsonify({
            "success": False,
            "error": f"Invalid input: {str(e)}"
        }), 400
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        return jsonify({
            "success": False,
            "error": f"Prediction error: {str(e)}"
        }), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "model_loaded": ai_model is not None,
        "version": "2.0.0"
    }), 200


@app.errorhandler(404)
def not_found(e):
    return jsonify({
        "success": False,
        "error": "Endpoint not found"
    }), 404


@app.errorhandler(500)
def server_error(e):
    return jsonify({
        "success": False,
        "error": "Internal server error"
    }), 500


if __name__ == '__main__':
    # Run on localhost:5000 for development
    # For Android emulator, use 10.0.2.2:5000
    app.run(host='127.0.0.1', port=5000, debug=False)
