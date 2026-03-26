import pandas as pd
import numpy as np
import random
import os

def calculate_ber(snr, noise, coding, modulation):
    """
    Simulates Bit Error Rate based on SNR, noise penalty, coding gain, and modulation complexity.
    """
    # Base BER exponentially decreasing with SNR
    base_ber = 10 ** (-(snr / 10.0))
    
    # Noise penalty
    ber = base_ber * (1 + noise)
    
    # Modulation impact (higher complexity = higher BER for the same SNR)
    mod_penalty = {'QPSK': 1.0, '16-QAM': 2.0, '64-QAM': 4.0, 'FSK': 1.5}
    ber *= mod_penalty.get(modulation, 1.0)
    
    # Coding improvement (lower is better, cuts down BER)
    coding_gain = {'None': 1.0, 'RS': 0.1, 'Hamming': 0.2, 'Convolutional': 0.05}
    ber *= coding_gain.get(coding, 1.0)
    
    return min(ber, 0.5) # Cap at maximum 0.5 (random guess)

def calculate_latency(file_size_kb, encoding, coding, modulation):
    """
    Simulates transmission latency (ms) based on processing delays and transmission rates.
    """
    # Base latency based on file size
    base_lat = file_size_kb * 0.1 # ms per KB baseline
    
    # Encoding processing time overhead
    enc_latency_factor = {'None': 0, 'AES-128': 2, 'AES-256': 4, 'ChaCha20': 1.5}
    lat = base_lat + (file_size_kb * enc_latency_factor.get(encoding, 0) * 0.01)
    
    # Coding processing time overhead
    cod_latency_factor = {'None': 0, 'RS': 1.5, 'Hamming': 1.0, 'Convolutional': 2.5}
    lat += (file_size_kb * cod_latency_factor.get(coding, 0) * 0.01)
    
    # Modulation transmission speed factor (higher order = faster = less latency)
    mod_speed = {'QPSK': 1.0, '16-QAM': 0.5, '64-QAM': 0.25, 'FSK': 1.2}
    lat *= mod_speed.get(modulation, 1.0)
    
    return lat

def generate_dataset(num_scenarios=1000, output_dir="."):
    """
    Generates dummy scenarios, evaluates configurations, scores them, and saves labeled dataset.
    """
    file_types = ['image', 'text', 'binary', 'pdf']
    encodings = ['AES-128', 'AES-256', 'ChaCha20', 'None']
    codings = ['RS', 'Hamming', 'Convolutional', 'None']
    modulations = ['QPSK', '16-QAM', '64-QAM', 'FSK']
    
    # Generate random base scenarios
    scenarios = []
    for _ in range(num_scenarios):
        scenarios.append({
            'file_type': random.choice(file_types),
            'file_size_kb': round(random.uniform(10.0, 5000.0), 2),
            'snr': round(random.uniform(5.0, 30.0), 2),
            'noise_level': round(random.uniform(0.01, 0.5), 3)
        })
    
    raw_data = []
    best_labels_data = []
    
    # For each scenario, trial all combinations
    for sc in scenarios:
        best_score = -float('inf')
        best_config = None
        best_metrics = None
        
        for enc in encodings:
            for cod in codings:
                for mod in modulations:
                    ber = calculate_ber(sc['snr'], sc['noise_level'], cod, mod)
                    latency = calculate_latency(sc['file_size_kb'], enc, cod, mod)
                    
                    # Define success threshold (BER < 5% and moderate latency)
                    success = 1 if (ber < 0.05 and latency < 3000) else 0
                    
                    # Scoring logic per requirements
                    # Normalize latency term slightly so it does not overpower other features
                    lat_norm = max(latency / 1000.0, 0.001) 
                    score = 0.6 * (1 - ber) + 0.3 * success + 0.1 * (1 / lat_norm)
                    
                    row = {
                        'file_type': sc['file_type'],
                        'file_size_kb': sc['file_size_kb'],
                        'snr': sc['snr'],
                        'noise_level': sc['noise_level'],
                        'encoding': enc,
                        'coding': cod,
                        'modulation': mod,
                        'ber': ber,
                        'latency': latency,
                        'success': success,
                        'score': score
                    }
                    raw_data.append(row)
                    
                    # Track optimal configuration
                    if score > best_score:
                        best_score = score
                        best_config = {'encoding': enc, 'coding': cod, 'modulation': mod}
                        best_metrics = {'ber': ber, 'latency': latency, 'success': success}
        
        # Save the single best config for this scenario as the training target
        best_row = {
            'file_type': sc['file_type'],
            'file_size_kb': sc['file_size_kb'],
            'snr': sc['snr'],
            'noise_level': sc['noise_level'],
            'encoding': best_config['encoding'], # Target Variable 1
            'coding': best_config['coding'],     # Target Variable 2
            'modulation': best_config['modulation'], # Target Variable 3
            'ber': best_metrics['ber'],
            'latency': best_metrics['latency'],
            'success': best_metrics['success'],
            'optimal_config': f"{best_config['encoding']}+{best_config['coding']}+{best_config['modulation']}"
        }
        best_labels_data.append(best_row)
        
    raw_df = pd.DataFrame(raw_data)
    labeled_df = pd.DataFrame(best_labels_data)
    
    raw_path = os.path.join(output_dir, "raw_transmission_data.csv")
    labeled_path = os.path.join(output_dir, "labeled_transmission_data.csv")
    
    # Updated required columns to include optimal_config
    req_cols_labeled = ['file_type', 'file_size_kb', 'snr', 'noise_level', 'encoding', 'coding', 'modulation', 'ber', 'latency', 'success', 'optimal_config']
    
    raw_df.to_csv(raw_path, index=False)
    labeled_df[req_cols_labeled].to_csv(labeled_path, index=False)
    
    print(f"Generated {len(raw_df)} raw samples and {len(labeled_df)} optimal labeled scenarios.")
    print(f"Saved to:\n - {raw_path}\n - {labeled_path}")

if __name__ == "__main__":
    random.seed(42)
    output_directory = os.path.dirname(os.path.abspath(__file__))
    print("Starting dataset generation...")
    generate_dataset(1000, output_directory)
    print("Dataset generation complete.")
