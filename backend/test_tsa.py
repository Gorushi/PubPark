import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import StandardScaler
from statsmodels.tsa.stattools import adfuller

CACHE_FILE = 'parking_cache.json'

def analyze_parking_demand():
    df = pd.read_json(CACHE_FILE).T
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    
    df.set_index('timestamp', inplace=True)
    df.sort_index(inplace=True)