import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import StandardScaler
from statsmodels.tsa.stattools import adfuller

CACHE_FILE = 'parking_cache.json'

def analyze_parking_demand():
    # 앞선 전처리 로직 반영 상태
    df = pd.read_json(CACHE_FILE).T
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df.set_index('timestamp', inplace=True)
    df.sort_index(inplace=True)
    df['pkfc_Available_ParkingLots_total'] = df['pkfc_Available_ParkingLots_total'].interpolate(method='linear')
    
    adf_res = adfuller(df['pkfc_Available_ParkingLots_total'])
    print(f"p-value: {adf_res[1]}")
    
    adf_res = adfuller(df['pkfc_Available_ParkingLots_total'])

    df['diff_target'] = df['pkfc_Available_ParkingLots_total'].diff()
    
    df['roll_mean'] = df['pkfc_Available_ParkingLots_total'].rolling(window=7).mean()
    df['roll_std'] = df['pkfc_Available_ParkingLots_total'].rolling(window=7).std()
    
    df['lag_1'] = df['pkfc_Available_ParkingLots_total'].shift(1)
    df['lag_2'] = df['pkfc_Available_ParkingLots_total'].shift(2)
    
    df['hour'] = df.index.hour
    df['dayofweek'] = df.index.dayofweek
    
    df.dropna(inplace=True)
    f_cols = ['lag_1', 'lag_2', 'hour', 'dayofweek']
    
    scaler = StandardScaler()
    f_cols = ['lag_1', 'lag_2', 'hour', 'dayofweek']
    df[f_cols] = scaler.fit_transform(df[f_cols])
    
    border = int(len(df) * 0.8)
    train, test = df.iloc[:border], df.iloc[border:]