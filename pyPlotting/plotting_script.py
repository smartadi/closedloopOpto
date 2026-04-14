"""
Python equivalent of plottingScript.m
Plotting analysis across sessions for brain imaging data
"""

import numpy as np
import matplotlib.pyplot as plt
from scipy.io import loadmat
from pathlib import Path
import csv

# Configuration for different experimental sessions
class MouseSession:
    def __init__(self, mn, td, en, trials):
        self.mn = mn
        self.td = td
        self.en = en
        self.trials = trials
        self.data = None
        self.d = None


class ExperimentData:
    """Class to hold all experiment data, similar to MATLAB struct 'd'"""
    def __init__(self):
        self.input_params = None
        self.states = None
        self.params = None
        self.iputs = None
        self.en = None
        self.mn = None
        self.td = None
        self.inpTime = None
        self.inpVals = None
        self.lightRaw = None
        self.lightTime = None
        self.wfExp = None
        self.wfTime = None
        self.timeBlue = None
        self.motion = None
        self.mv = None
        self.svd = {}
        self.stimStarts = None
        self.stimEnds = None
        self.stimDur = None
        self.ref = -5  # Default reference value
    
    def print_structure(self):
        """Print all attributes and their shapes"""
        print("\n" + "=" * 70)
        print("ExperimentData Structure:")
        print("=" * 70)
        
        for attr_name in dir(self):
            # Skip private and method attributes
            if attr_name.startswith('_') or callable(getattr(self, attr_name)):
                continue
            
            value = getattr(self, attr_name)
            print(f"\n'{attr_name}':")
            print(f"  Type: {type(value)}")
            
            if isinstance(value, np.ndarray):
                print(f"  Shape: {value.shape}")
                print(f"  Dtype: {value.dtype}")
                if value.size > 0 and value.size <= 10:
                    print(f"  Values: {value.ravel()}")
                elif value.size > 0:
                    flat = value.ravel()
                    print(f"  Preview (first 5): {flat[:5]}")
            elif isinstance(value, dict):
                print(f"  Keys: {list(value.keys())}")
                for k, v in value.items():
                    if isinstance(v, np.ndarray):
                        print(f"    '{k}': shape {v.shape}, dtype {v.dtype}")
                    else:
                        print(f"    '{k}': {type(v)}")
            elif value is None:
                print(f"  Value: None")
            else:
                val_str = str(value)
                if len(val_str) > 100:
                    val_str = val_str[:100] + "..."
                print(f"  Value: {val_str}")
        
        print("=" * 70)


def load_data(server_root, mn, td, en):
    """
    Load experimental data from server directory
    Python equivalent of loadData.m
    
    Parameters:
    - server_root: Path to experiment data directory
    - mn: Mouse name
    - td: Date
    - en: Experiment number
    """
    d = ExperimentData()
    d.mn = mn
    d.td = td
    d.en = en
    
    server_path = Path(server_root)
    
    try:
        # Load input parameters
        input_params_file = server_path / 'input_params.csv'
        if input_params_file.exists():
            d.input_params = np.loadtxt(input_params_file, delimiter=',')
            print(f"Loaded input_params: {d.input_params.shape}")
        
        # Load states
        states_file = server_path / 'states.csv'
        if states_file.exists():
            d.states = np.loadtxt(states_file, delimiter=' ')
            print(f"Loaded states: {d.states.shape}")
        
        # Load params
        params_file = server_path / 'params.mat'
        if params_file.exists():
            d.params = loadmat(str(params_file))
            print(f"Loaded params.mat")
        
        # Load input amplitudes
        iputs_file = server_path / 'input_amps.csv'
        if iputs_file.exists():
            d.iputs = np.loadtxt(iputs_file, delimiter=' ')
            print(f"Loaded input_amps")
        
        # Load timeline data (NPY files)
        try:
            light_raw_file = server_path / 'lightCommand.raw.npy'
            light_time_file = server_path / 'lightCommand.timestamps_Timeline.npy'
            if light_raw_file.exists():
                d.lightRaw = np.load(light_raw_file)
                d.lightTime = np.load(light_time_file)
        except:
            try:
                d.lightRaw = np.load(server_path / 'lightCommand638.raw.npy')
                d.lightTime = np.load(server_path / 'lightCommand638.timestamps_Timeline.npy')
            except:
                print("Warning: Could not load light command data")
        
        # Load widefield data
        try:
            d.wfExp = np.load(server_path / 'widefieldExposure.timestamps_Timeline.npy')
            d.wfTime = np.load(server_path / 'widefieldExposure.raw.npy')
            
            # Extract blue light timestamps
            wf_times = d.wfExp[(d.wfTime[1:] > 1) & (d.wfTime[:-1] <= 1)]
            d.timeBlue = wf_times[::2]  # Every other frame (blue frames)
            print(f"Loaded timeBlue: {d.timeBlue.shape}")
        except Exception as e:
            print(f"Warning: Could not load widefield data: {e}")
        
        # Load motion data
        motion_file = server_path / 'face_proc.mat'
        if motion_file.exists():
            d.motion = loadmat(str(motion_file))
            if 'motSVD_0' in d.motion:
                d.mv = d.motion['motSVD_0'][::2, 0]  # Every other frame
            elif 'motion_1' in d.motion:
                d.mv = d.motion['motion_1'][::2]
            print(f"Loaded motion data")
        
        # Load SVD components
        try:
            nSV = 2000
            U_file = server_path / 'blue' / 'svdSpatialComponents.npy'
            V_file = server_path / 'blue' / 'svdTemporalComponents.npy'
            t_file = server_path / 'blue' / 'svdTemporalComponents.timestamps.npy'
            mimg_file = server_path / 'blue' / 'meanImage.npy'
            
            if U_file.exists():
                d.svd['U'] = np.load(U_file)[:, :nSV]
                d.svd['V'] = np.load(V_file)[:nSV, :]
                d.svd['t'] = np.load(t_file)
                d.svd['mimg'] = np.load(mimg_file)
                d.svd['nSV'] = nSV
                print(f"Loaded SVD components")
        except Exception as e:
            print(f"Warning: Could not load SVD data: {e}")
            
    except Exception as e:
        print(f"Error loading data: {e}")
    
    return d


def find_stims(d, mode=1):
    """
    Find stimulus start and end times
    Python equivalent of findStims.m
    
    Parameters:
    - d: ExperimentData object
    - mode: 0 = from stim search, 1 = from param data
    """
    input_params = d.input_params
    t = d.timeBlue
    
    if mode == 0:
        # Find stimulus times from input values
        stim_times = d.inpTime[(d.inpVals[1:] > 0.1) & (d.inpVals[:-1] <= 0.1)]
        ds = np.where(np.diff(np.concatenate([[0], stim_times])) > 2)[0]
        d.stimStarts = stim_times[ds]
        d.stimEnds = stim_times[ds[1:] - 1]
        d.stimDur = d.stimEnds - d.stimStarts[:-1]
    else:
        # Use parameter data
        dur = d.params.get('dur', 3)
        if isinstance(dur, np.ndarray):
            dur = dur[0, 0]
        
        a1 = input_params[:, 1].astype(int)  # Start indices
        a2 = (input_params[:, 1] + dur * 35).astype(int)  # End indices (35 Hz sampling)
        
        d.stimStarts = t[a1]
        d.stimEnds = t[a2]
    
    print(f"Found {len(d.stimStarts)} stimulus periods")
    return d


def initialize_data(mn, en, td, data_dir=None):
    """
    Initialize experiment data
    Python equivalent of initialize_data.m
    
    Parameters:
    - mn: Mouse name
    - en: Experiment number
    - td: Date (format: YYYY-MM-DD)
    - data_dir: Optional custom data directory
    """
    if data_dir is None:
        # Construct default path
        data_dir = Path(__file__).parent.parent / 'data' / mn / td / f'exp{en}'
    else:
        data_dir = Path(data_dir)
    
    print(f"\nInitializing data for {mn}, {td}, experiment {en}")
    print(f"Data directory: {data_dir}")
    
    # Load data
    d = load_data(str(data_dir), mn, td, en)


    """
    # Find stimulus times
    d = find_stims(d, mode=1)
    
    # Set pixel configuration (from MATLAB code)
    if d.params and 'pixel' in d.params:
        pixel = d.params['pixel']
        if isinstance(pixel, np.ndarray):
            pixel = pixel.ravel()
        
        # Pixel offsets
        offsetx = 20
        offsety = -40
        
        # Create pixel grid
        px = np.array([200, 300, 150, 200, 300, 350, 100, 200, 300, 400, 100, 200, 300, 400]) + offsetx
        py = np.array([150, 150, 225, 225, 225, 225, 325, 325, 325, 325, 425, 425, 425, 425]) + offsety
        
        frame = np.column_stack([
            np.concatenate([[pixel[0]], px]),
            np.concatenate([[pixel[1]], py])
        ])
        
        d.params['pixels'] = frame
    """
    
    # Print structure of loaded data
    d.print_structure()
    
    return d


def controller_data(data_dict, d, num_trials):
    """
    Process controller data for analysis
    Python equivalent of controllerData.m
    
    Parameters:
    - data_dict: Dictionary containing dFk and other data
    - d: ExperimentData object
    - num_trials: Number of trials to analyze
    """
    print(f"\nProcessing controller data for {num_trials} trials...")
    
    # Create trial mask
    total_trials = len(d.input_params)
    trials = np.zeros(total_trials)
    trials[-num_trials:] = 1  # Last num_trials are included
    
    dFk = data_dict['dFk']
    
    # Find no-control (nc) and with-control (wc) trials
    nc = np.where((d.input_params[:, 2] == 0) & (trials == 1))[0]
    wc = np.where((d.input_params[:, 2] == 1) & (trials == 1))[0]
    
    print(f"No-control trials: {len(nc)}, With-control trials: {len(wc)}")
    
    dur = d.params.get('dur', 3)
    if isinstance(dur, np.ndarray):
        dur = dur[0, 0]
    
    t = d.timeBlue
    
    # Extract motion data
    if d.motion and 'motion_1' in d.motion:
        mv1 = d.motion['motion_1'][::2]
    elif d.mv is not None:
        mv1 = d.mv
    else:
        mv1 = np.zeros(len(t))
    
    # Process no-control trials
    ncDfk = []
    pncDfk = []
    ncmotion = []
    
    for trial_idx in nc:
        i = np.argmin(np.abs(t - d.stimStarts[trial_idx]))
        ncDfk.append(dFk[i-35:i+35*(int(dur)+1)])
        pncDfk.append(dFk[i-35*10:i+35*(int(dur)+3)])
        
        if len(mv1) > i + 35*(int(dur)+2):
            ncmotion.append(mv1[i-35*10:i+35*(int(dur)+2)])
    
    ncDfk = np.array(ncDfk) if ncDfk else np.array([])
    pncDfk = np.array(pncDfk) if pncDfk else np.array([])
    
    # Process with-control trials
    wcDfk = []
    pwcDfk = []
    wcmotion = []
    
    for trial_idx in wc:
        i = np.argmin(np.abs(t - d.stimStarts[trial_idx]))
        wcDfk.append(dFk[i-35:i+35*(int(dur)+1)])
        pwcDfk.append(dFk[i-35*10:i+35*(int(dur)+3)])
        
        if len(mv1) > i + 35*(int(dur)+2):
            wcmotion.append(mv1[i-35*10:i+35*(int(dur)+2)])
    
    wcDfk = np.array(wcDfk) if wcDfk else np.array([])
    pwcDfk = np.array(pwcDfk) if pwcDfk else np.array([])
    
    # Compute error norms and variances
    ref = getattr(d, 'ref', -5)
    
    er_ncDfk = []
    vr_ncDfk = []
    for trial_idx in nc:
        i = np.argmin(np.abs(t - d.stimStarts[trial_idx]))
        segment = dFk[i:i+35*int(dur)]
        er_ncDfk.append(np.linalg.norm(segment - ref))
        vr_ncDfk.append(np.var(segment))
    
    er_wcDfk = []
    vr_wcDfk = []
    for trial_idx in wc:
        i = np.argmin(np.abs(t - d.stimStarts[trial_idx]))
        segment = dFk[i:i+35*int(dur)]
        er_wcDfk.append(np.linalg.norm(segment - ref))
        vr_wcDfk.append(np.var(segment))
    
    # Update data dictionary
    result = data_dict.copy()
    result.update({
        'nc': nc,
        'wc': wc,
        'ncDfk': ncDfk,
        'wcDfk': wcDfk,
        'pncDfk': pncDfk,
        'pwcDfk': pwcDfk,
        'ncmotion': np.array(ncmotion) if ncmotion else np.array([]),
        'wcmotion': np.array(wcmotion) if wcmotion else np.array([]),
        'er_ncDfk': np.array(er_ncDfk),
        'er_wcDfk': np.array(er_wcDfk),
        'vr_ncDfk': np.array(vr_ncDfk),
        'vr_wcDfk': np.array(vr_wcDfk),
    })
    
    print("Controller data processing complete")
    return result

# Initialize all mouse sessions
mice = {
    'm1': MouseSession('AL_0033', '2025-01-20', 3, 120),
    'm2': MouseSession('AL_0033', '2025-02-12', 2, 200),
    'm3': MouseSession('AL_0033', '2025-02-24', 2, 200),
    'm4': MouseSession('AL_0033', '2025-02-26', 2, 200),
    'm5': MouseSession('AL_0033', '2025-03-04', 1, 60),
    'm6': MouseSession('AL_0033', '2025-03-05', 2, 30),
    'm7': MouseSession('AL_0033', '2025-03-20', 4, 100),
    'm8': MouseSession('AL_0033', '2025-04-15', 2, 60),
    'm9': MouseSession('AL_0039', '2025-04-20', 1, 100),
    'm10': MouseSession('AL_0039', '2025-04-19', 1, 100),
    'm11': MouseSession('AL_0039', '2025-04-30', 3, 100),
    'm12': MouseSession('AL_0033', '2025-04-19', 1, 100),
    'm13': MouseSession('AL_0039', '2025-04-20', 2, 100),
}


def load_pixel_data(mn, td, en):
    """
    Load pixel data from .mat file
    Construct filename from mouse name, date, and experiment number
    """
    # Remove hyphens from date and extract month and day
    td_clean = td.replace('-', '')
    # Format: MMDDY where Y is experiment number (04191 = month 04, day 19, exp 1)
    month_day = td_clean[-4:]  # Get last 4 digits (MMDD)
    
    # Data files are in parent directory
    parent_dir = Path(__file__).parent.parent
    
    # Try different naming patterns
    patterns = [
        f"{mn}pixel{month_day}{en}.mat",
        f"{mn}pixels{month_day}{en}.mat",
        f"AL_{mn.split('_')[1]}pixel{month_day}{en}.mat",
        f"data{mn}_{td}_{en}.mat",
    ]
    
    for pattern in patterns:
        filepath = parent_dir / pattern
        if filepath.exists():
            print(f"Loading: {filepath}")
            mat_data = loadmat(str(filepath))
            
            # Display data structure information
            print(f"\nData type: {type(mat_data)}")
            print(f"Number of keys: {len(mat_data)}")
            print("\nStructure of loaded .mat file:")
            print("-" * 70)
            
            for key in mat_data.keys():
                value = mat_data[key]
                if not key.startswith('__'):  # Skip metadata keys
                    print(f"\nKey: '{key}'")
                    print(f"  Type: {type(value)}")
                    if isinstance(value, np.ndarray):
                        print(f"  Shape: {value.shape}")
                        print(f"  Dtype: {value.dtype}")
                        if value.size > 0:
                            flat = value.ravel()
                            preview = flat[:5] if flat.size >= 5 else flat
                            print(f"  Preview (first 5 elements): {preview}")
                    else:
                        print(f"  Value: {repr(value)[:100]}")
            
            print("-" * 70)
            return mat_data
    
    print(f"Warning: Could not find data file for {mn}, {td}, {en}")
    print(f"Tried patterns: {patterns}")
    return None


def compute_variance_analysis(dFk, stim_starts, t, dur=3):
    """
    Compute variance analysis for trials
    
    Parameters:
    - dFk: fluorescence signal
    - stim_starts: stimulus start times
    - t: time vector
    - dur: duration in seconds
    """
    # Extract trials around stimulus
    trials_data = []
    er_vals = []
    
    for stim_start in stim_starts:
        # Find index closest to stimulus start
        i = np.argmin(np.abs(t - stim_start))
        
        # Extract 3 seconds before to (dur+3) seconds after
        # Assuming 35 Hz sampling rate
        pre_samples = 35 * 3
        post_samples = 35 * (dur + 3)
        
        if i - pre_samples >= 0 and i + post_samples < len(dFk):
            trial_segment = dFk[i - pre_samples:i + post_samples]
            trials_data.append(trial_segment)
            
            # Compute error norm during stimulation
            stim_segment = dFk[i:i + 35 * dur]
            er_vals.append(np.linalg.norm(stim_segment + 5))
    
    trials_data = np.array(trials_data)
    variance = np.var(trials_data, axis=0) if len(trials_data) > 0 else np.array([])
    
    return {
        'trials': trials_data,
        'variance': variance,
        'error_norms': np.array(er_vals)
    }


def plot_trial_traces(trials_data, title='Trial Traces', color='m', save_name=None):
    """
    Plot individual trial traces with mean
    """
    # Time vector: -3 to 6 seconds, 35 Hz sampling
    tp = np.arange(-3, 6, 1/35)
    ref = -5 * np.ones_like(tp)
    tpr = np.arange(0, 3, 1/35)
    la = -7 * np.ones_like(tpr)
    
    # Adjust time vector to match data length
    if len(tp) != trials_data.shape[1]:
        tp = np.linspace(-3, 6, trials_data.shape[1])
    if len(tpr) > trials_data.shape[1]:
        tpr = tpr[:trials_data.shape[1]]
        la = la[:trials_data.shape[1]]
    
    fig, ax = plt.subplots(figsize=(12, 6))
    
    # Plot individual traces
    for trial in trials_data:
        ax.plot(tp, trial, color=color, alpha=0.3, linewidth=0.5)
    
    # Plot mean
    mean_trace = np.mean(trials_data, axis=0)
    ax.plot(tp, mean_trace, 'k', linewidth=3, label='Mean')
    
    # Reference line
    ax.plot(tp, ref, '--g', linewidth=3, label='Target')
    
    # Laser period indicator
    laser_tp = tpr[tpr <= 3]
    laser_la = la[:len(laser_tp)]
    ax.plot(laser_tp, laser_la, 'r', linewidth=4, label='Laser')
    
    # Vertical lines at stimulus boundaries
    ax.axvline(x=0, color='k', linewidth=0.5, linestyle='-')
    ax.axvline(x=3, color='k', linewidth=0.5, linestyle='-')
    
    ax.set_xlabel('Time (s)', fontsize=12)
    ax.set_ylabel('dF/F', fontsize=12)
    ax.set_title(title, fontsize=14)
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    
    if save_name:
        # plt.savefig(save_name, format='svg', dpi=300)
        print(f"Plot ready (not saved): {save_name}")
    
    return fig, ax


def plot_variance_comparison(var_nc, var_wc, save_name=None):
    """
    Plot variance comparison between no control and with control conditions
    """
    # Time vector: -3 to 6 seconds, 35 Hz sampling
    tp = np.arange(-3, 6, 1/35)
    
    # Adjust if needed
    if len(tp) != len(var_nc):
        tp = np.linspace(-3, 6, len(var_nc))
    
    fig, ax = plt.subplots(figsize=(12, 6))
    
    ax.plot(tp, var_nc, 'm', linewidth=2, label='No Control')
    ax.plot(tp, var_wc, 'b', linewidth=2, label='With Control')
    
    # Vertical lines at stimulus boundaries
    ax.axvline(x=0, color='k', linewidth=0.5, linestyle='-')
    ax.axvline(x=3, color='k', linewidth=0.5, linestyle='-')
    
    ax.set_xlabel('Time (s)', fontsize=12)
    ax.set_ylabel('Variance', fontsize=12)
    ax.set_title('Variance Comparison: Control vs No Control', fontsize=14)
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    
    if save_name:
        # plt.savefig(save_name, format='svg', dpi=300)
        print(f"Plot ready (not saved): {save_name}")
    
    return fig, ax


# Example usage for a single session
def analyze_single_session(mn='AL_0039', td='2025-04-19', en=1):
    """
    Analyze a single experimental session
    """
    print(f"\nAnalyzing session: {mn}, {td}, experiment {en}")
    
    # Load data
    mat_data = load_pixel_data(mn, td, en)
    
    if mat_data is None:
        print("No data loaded. Exiting.")
        return
    
    # Extract dFk if available
    if 'dFk' in mat_data:
        dFk = mat_data['dFk'].ravel()
        print(f"Loaded dFk with shape: {dFk.shape}")
        
        # Plot the full signal
        fig, ax = plt.subplots(figsize=(14, 6))
        ax.plot(dFk, linewidth=0.5)
        ax.set_xlabel('Sample Index')
        ax.set_ylabel('dF/F')
        ax.set_title(f'Full dF/F Signal - {mn} {td} Exp {en}')
        ax.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.show()
        
        return dFk
    else:
        print("Warning: 'dFk' not found in mat file")
        print(f"Available keys: {[k for k in mat_data.keys() if not k.startswith('__')]}")
        return None


if __name__ == "__main__":
    # Example 1: Simple analysis - just load and plot dFk
    print("=" * 70)
    print("EXAMPLE 1: Simple dFk loading and plotting")
    print("=" * 70)
    
    dFk = analyze_single_session(mn='AL_0039', td='2025-04-19', en=1)
    
    # Example 2: Full analysis with initialize_data and controller_data
    # (This requires the full experimental data directory structure)
    print("\n" + "=" * 70)
    print("EXAMPLE 2: Full analysis with initialize_data and controller_data")
    print("=" * 70)
    print("Note: This requires full experimental data directory.")
    print("Demonstrating with mock trial data instead...")
    
    # # If you have trial and stimulus timing information, you can do full analysis
    # # Example of creating synthetic variance plots
    # if dFk is not None and len(dFk) > 1000:
    #     print("\nCreating example variance analysis...")
        
    #     # Create mock trial data for demonstration
    #     n_trials = 20
    #     trial_length = 315  # 9 seconds at 35 Hz
        
    #     mock_trials_nc = []
    #     mock_trials_wc = []
        
    #     for i in range(n_trials):
    #         start_idx = np.random.randint(0, len(dFk) - trial_length)
    #         mock_trials_nc.append(dFk[start_idx:start_idx + trial_length])
    #         # With control: add some noise reduction
    #         mock_trials_wc.append(dFk[start_idx:start_idx + trial_length] * 0.7)
        
    #     mock_trials_nc = np.array(mock_trials_nc)
    #     mock_trials_wc = np.array(mock_trials_wc)
        
    #     # Plot trial traces
    #     plot_trial_traces(mock_trials_nc, 
    #                      title='No Control Trials', 
    #                      color='m',
    #                      save_name='figure_nc.svg')
        
    #     plot_trial_traces(mock_trials_wc, 
    #                      title='With Control Trials', 
    #                      color='b',
    #                      save_name='figure_wc.svg')
        
    #     # Plot variance comparison
    #     var_nc = np.var(mock_trials_nc, axis=0)
    #     var_wc = np.var(mock_trials_wc, axis=0)
        
    #     plot_variance_comparison(var_nc, var_wc, save_name='figure_var.svg')
        
    #     plt.show()
    
    # Example 3: Using the new functions (if you have full data directory)
    print("\n" + "=" * 70)
    print("EXAMPLE 3: Demonstrate ExperimentData structure")
    print("=" * 70)
    print("Creating a sample ExperimentData object to show structure...\n")
    
    # Create a sample ExperimentData object
    sample_d = ExperimentData()
    sample_d.mn = 'AL_0039'
    sample_d.td = '2025-04-19'
    sample_d.en = 1
    sample_d.input_params = np.array([[1, 100, 0], [2, 200, 1]])
    sample_d.timeBlue = np.linspace(0, 100, 1000)
    sample_d.stimStarts = np.array([10.0, 20.0, 30.0])
    sample_d.stimEnds = np.array([13.0, 23.0, 33.0])
    sample_d.params = {'dur': 3, 'pixel': [200, 150]}
    
    # Print the structure
    sample_d.print_structure()
    
    print("\n" + "=" * 70)
    print("Usage instructions:")
    print("=" * 70)
    print("""
    # If you have the full experimental data directory structure:
    
    # Step 1: Initialize experiment data (will automatically print structure)
    d = initialize_data(mn='AL_0039', en=1, td='2025-04-19', 
                       data_dir='/path/to/data/AL_0039/2025-04-19/exp1')
    
    # Step 2: Load pixel dFk data
    mat_data = load_pixel_data('AL_0039', '2025-04-19', 1)
    
    # Step 3: Process controller data
    processed_data = controller_data(mat_data, d, num_trials=100)
    
    # Step 4: Access processed trial data
    nc_trials = processed_data['ncDfk']  # No-control trials
    wc_trials = processed_data['wcDfk']  # With-control trials
    
    # Step 5: Plot
    plot_trial_traces(processed_data['pncDfk'], 
                     title='No Control Trials',
                     color='m', 
                     save_name='nc_trials.svg')
    plot_trial_traces(processed_data['pwcDfk'], 
                     title='With Control Trials',
                     color='b',
                     save_name='wc_trials.svg')
    """)
