from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import sys
import json
from inference import AdaptiveTransmissionModel
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Initialize the AI model
try:
    predictor = AdaptiveTransmissionModel()
    logger.info("✓ Adaptive Transmission Model loaded successfully")
except FileNotFoundError as e:
    logger.warning(f"⚠ Model file not found: {e}. Running in demo mode.")
    predictor = None

# Supported file types and encryption methods
SUPPORTED_FILE_TYPES = {
    'image': {
        'extensions': ['png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp'],
        'recommended_encryption': 'SAIC-ACT',
        'description': 'Image files optimized for spectrogram transmission'
    },
    'text': {
        'extensions': ['txt', 'json', 'xml', 'csv', 'md', 'dart', 'js'],
        'recommended_encryption': 'AES-256-GCM',
        'description': 'Text files with compression support'
    },
    'document': {
        'extensions': ['pdf'],
        'recommended_encryption': 'AES-256-GCM',
        'description': 'Structured documents'
    },
    'binary': {
        'extensions': ['bin', 'exe', 'dll', 'so', 'zip', 'tar', 'gz'],
        'recommended_encryption': 'ChaCha20-Poly1305',
        'description': 'Binary/executable files'
    }
}

ENCRYPTION_METHODS = {
    'SAIC-ACT': {
        'name': 'Spectrogram Adaptive Image Cipher for Acoustic Transmission',
        'security_level': 0.95,
        'performance': 0.85,
        'streaming': False,
        'authenticated': False,
        'suited_for': ['image', 'binary']
    },
    'AES-256-GCM': {
        'name': 'Advanced Encryption Standard 256-bit Galois/Counter Mode',
        'security_level': 1.0,
        'performance': 0.9,
        'streaming': True,
        'authenticated': True,
        'suited_for': ['image', 'text', 'document', 'binary']
    },
    'ChaCha20-Poly1305': {
        'name': 'Modern Stream Cipher with Polynomial MAC Authentication',
        'security_level': 0.98,
        'performance': 0.95,
        'streaming': True,
        'authenticated': True,
        'suited_for': ['image', 'text', 'document', 'binary']
    },
    'XOR-Crypto': {
        'name': 'Lightweight XOR-based Encryption',
        'security_level': 0.4,
        'performance': 1.0,
        'streaming': True,
        'authenticated': False,
        'suited_for': ['text', 'binary']
    }
}


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'VisioLock++ Adaptive Transmission API',
        'version': '2.0.0',
        'ai_model_loaded': predictor is not None,
        'timestamp': __import__('datetime').datetime.now().isoformat()
    }), 200


@app.route('/api/predict', methods=['POST'])
def predict_configuration():
    """
    Predict optimal transmission configuration based on file type and channel conditions
    
    Request JSON:
    {
        "file_type": "image|text|document|binary",
        "file_size_kb": float,
        "snr": float (dB),
        "noise_level": float (0.0-1.0),
        "encryption_method": "SAIC-ACT|AES-256-GCM|ChaCha20-Poly1305|XOR-Crypto|auto"
    }
    
    Returns:
    {
        "encoding": str,
        "coding": str,
        "modulation": str,
        "recommended_encryption": str,
        "reasoning": str
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400

        file_type = data.get('file_type', 'binary')
        file_size_kb = float(data.get('file_size_kb', 100.0))
        snr = float(data.get('snr', 15.0))
        noise_level = float(data.get('noise_level', 0.1))
        encryption_method = data.get('encryption_method', 'auto')

        # Validate inputs
        if file_size_kb < 0 or snr < 0 or not (0 <= noise_level <= 1):
            return jsonify({'error': 'Invalid parameter values'}), 400

        # Normalize file type
        file_type = normalize_file_type(file_type)

        # Get AI prediction if model is available
        if predictor:
            config = predictor.predict_config(file_type, file_size_kb, snr, noise_level)
        else:
            # Fallback to rule-based recommendations
            config = get_fallback_configuration(file_type, snr)

        # Select optimal encryption method
        if encryption_method == 'auto':
            encryption_method = select_optimal_encryption(file_type, snr, noise_level)

        # Validate encryption method
        if encryption_method not in ENCRYPTION_METHODS:
            encryption_method = select_optimal_encryption(file_type, snr, noise_level)

        # Generate reasoning
        reasoning = generate_reasoning(file_type, file_size_kb, snr, noise_level, encryption_method)

        response = {
            'encoding': config.get('encoding', 'default'),
            'coding': config.get('coding', 'RS'),
            'modulation': config.get('modulation', '16-QAM'),
            'recommended_encryption': encryption_method,
            'reasoning': reasoning,
            'metadata': {
                'input_file_type': file_type,
                'file_size_kb': file_size_kb,
                'snr_db': snr,
                'noise_level': noise_level,
                'calculation_timestamp': __import__('datetime').datetime.now().isoformat()
            }
        }

        return jsonify(response), 200

    except ValueError as e:
        return jsonify({'error': f'Invalid input: {str(e)}'}), 400
    except Exception as e:
        logger.error(f"Prediction error: {str(e)}")
        return jsonify({'error': f'Prediction failed: {str(e)}'}), 500


@app.route('/api/encryption-methods', methods=['GET'])
def get_encryption_methods():
    """Get available encryption methods"""
    return jsonify({
        'available_methods': ENCRYPTION_METHODS,
        'total_methods': len(ENCRYPTION_METHODS)
    }), 200


@app.route('/api/file-types', methods=['GET'])
def get_file_types():
    """Get supported file types"""
    return jsonify({
        'supported_types': SUPPORTED_FILE_TYPES,
        'total_types': len(SUPPORTED_FILE_TYPES)
    }), 200


@app.route('/api/recommend-encryption', methods=['POST'])
def recommend_encryption():
    """
    Get encryption method recommendations for specific file type and conditions
    
    Request JSON:
    {
        "file_type": "image|text|document|binary",
        "file_size_kb": float,
        "snr": float,
        "noise_level": float,
        "priority": "security|performance|balanced"
    }
    """
    try:
        data = request.get_json()
        file_type = normalize_file_type(data.get('file_type', 'binary'))
        file_size_kb = float(data.get('file_size_kb', 100.0))
        snr = float(data.get('snr', 15.0))
        noise_level = float(data.get('noise_level', 0.1))
        priority = data.get('priority', 'balanced')

        # Get recommendations
        recommendations = get_encryption_recommendations(
            file_type, file_size_kb, snr, noise_level, priority
        )

        return jsonify({
            'recommendations': recommendations,
            'priority': priority,
            'file_type': file_type
        }), 200

    except Exception as e:
        logger.error(f"Recommendation error: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/analyze-file', methods=['POST'])
def analyze_file():
    """
    Get transmission configuration recommendations for a file
    
    Request JSON:
    {
        "file_name": str,
        "file_size_kb": float,
        "snr": float,
        "noise_level": float
    }
    """
    try:
        data = request.get_json()
        file_name = data.get('file_name', 'file.bin')
        file_size_kb = float(data.get('file_size_kb', 100.0))
        snr = float(data.get('snr', 15.0))
        noise_level = float(data.get('noise_level', 0.1))

        # Determine file type from extension
        ext = file_name.split('.')[-1].lower()
        file_type = determine_file_type_by_extension(ext)

        # Get configuration
        config = {
            'file_name': file_name,
            'file_type': file_type,
            'estimated_transmission_time': estimate_transmission_time(file_size_kb),
            'recommended_settings': {}
        }

        if predictor:
            config['recommended_settings'] = predictor.predict_config(
                file_type, file_size_kb, snr, noise_level
            )
        else:
            config['recommended_settings'] = get_fallback_configuration(file_type, snr)

        config['recommended_encryption'] = select_optimal_encryption(file_type, snr, noise_level)

        return jsonify(config), 200

    except Exception as e:
        logger.error(f"File analysis error: {str(e)}")
        return jsonify({'error': str(e)}), 500


# Helper functions

def normalize_file_type(file_type):
    """Normalize file type to standard category"""
    file_type = file_type.lower().strip()
    if file_type in ['image', 'img', 'picture']:
        return 'image'
    elif file_type in ['text', 'txt', 'ascii']:
        return 'text'
    elif file_type in ['document', 'doc', 'pdf']:
        return 'document'
    return 'binary'


def determine_file_type_by_extension(extension):
    """Determine file type from file extension"""
    for file_type, info in SUPPORTED_FILE_TYPES.items():
        if extension in info['extensions']:
            return file_type
    return 'binary'


def select_optimal_encryption(file_type, snr, noise_level):
    """Select optimal encryption method based on conditions"""
    # For images: prefer SAIC-ACT if SNR is good
    if file_type == 'image' and snr > 12:
        return 'SAIC-ACT'

    # For text: prefer AES-GCM for strong security
    if file_type == 'text':
        return 'AES-256-GCM'

    # For documents: always use AES-GCM
    if file_type == 'document':
        return 'AES-256-GCM'

    # For binary with high noise: use ChaCha20 (faster)
    if noise_level > 0.3 and snr < 10:
        return 'ChaCha20-Poly1305'

    # For low-resource scenarios: XOR-Crypto
    if snr < 5:
        return 'XOR-Crypto'

    # Default: secure choice
    return 'AES-256-GCM'


def get_encryption_recommendations(file_type, file_size_kb, snr, noise_level, priority='balanced'):
    """Get ranked encryption recommendations"""
    recommendations = []

    for method, details in ENCRYPTION_METHODS.items():
        if file_type not in details['suited_for']:
            continue

        # Calculate score based on priority
        if priority == 'security':
            score = details['security_level'] * 0.7 + details['performance'] * 0.3
        elif priority == 'performance':
            score = details['performance'] * 0.7 + details['security_level'] * 0.3
        else:  # balanced
            score = (details['security_level'] + details['performance']) / 2

        # Adjust score based on channel conditions
        if noise_level > 0.3:
            score *= details['performance']  # Boost fast methods
        if snr < 10:
            score *= 0.8  # Slightly penalize for poor channel

        recommendations.append({
            'method': method,
            'score': round(score, 2),
            'reason': f"Suited for {file_type} with {priority} priority",
            **details
        })

    # Sort by score (descending)
    recommendations.sort(key=lambda x: x['score'], reverse=True)
    return recommendations[:3]  # Top 3 recommendations


def get_fallback_configuration(file_type, snr):
    """Fallback configuration when AI model is unavailable"""
    if snr > 20:
        encoding, coding, modulation = 'QAM', 'Turbo', '64-QAM'
    elif snr > 12:
        encoding, coding, modulation = 'PSK', 'RS', '16-QAM'
    elif snr > 5:
        encoding, coding, modulation = 'BPSK', 'ConvCode', 'BPSK'
    else:
        encoding, coding, modulation = 'OOK', 'Repetition', 'OOK'

    return {
        'encoding': encoding,
        'coding': coding,
        'modulation': modulation
    }


def generate_reasoning(file_type, file_size_kb, snr, noise_level, encryption):
    """Generate human-readable reasoning for recommendations"""
    reasons = []

    if file_type == 'image':
        reasons.append(f"Image file detected ({file_size_kb:.1f} KB)")
    elif file_type == 'text':
        reasons.append(f"Text file detected - text content is compressible")
    elif file_type == 'document':
        reasons.append(f"Structured document detected - PDF format")
    else:
        reasons.append(f"Binary file detected - no compression assumed")

    if snr > 20:
        reasons.append("Excellent channel quality - using robust modulation")
    elif snr > 12:
        reasons.append("Good channel quality - balanced configuration")
    elif snr > 5:
        reasons.append("Moderate channel quality - error correction recommended")
    else:
        reasons.append("Poor channel quality - maximum error correction enabled")

    reasons.append(f"Encryption: {encryption} for this file type and channel conditions")

    return "; ".join(reasons)


def estimate_transmission_time(file_size_kb):
    """Estimate transmission time in seconds (assuming 10 kbps basic rate)"""
    base_rate = 10.0  # kbps
    return file_size_kb / base_rate


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'error': 'Endpoint not found',
        'available_endpoints': [
            '/api/health',
            '/api/predict',
            '/api/encryption-methods',
            '/api/file-types',
            '/api/recommend-encryption',
            '/api/analyze-file'
        ]
    }), 404


@app.errorhandler(500)
def server_error(error):
    """Handle 500 errors"""
    logger.error(f"Server error: {str(error)}")
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_ENV', 'production').lower() == 'development'

    logger.info(f"Starting VisioLock++ Adaptive Transmission API v2.0.0")
    logger.info(f"Server running on http://0.0.0.0:{port}")
    logger.info(f"Debug mode: {debug}")
    logger.info(f"Supported file types: {list(SUPPORTED_FILE_TYPES.keys())}")
    logger.info(f"Available encryption methods: {list(ENCRYPTION_METHODS.keys())}")

    app.run(host='0.0.0.0', port=port, debug=debug)
