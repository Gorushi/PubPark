import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import StandardScaler
from statsmodels.tsa.stattools import adfuller

CACHE_FILE = 'parking_cache.json'

def analyze_parking_demand():
    print("[시계열 분석] 파이프라인 가동")
    
    try:
        df = pd.read_json(CACHE_FILE).T
    except Exception as e:
        print(f"캐시 파일 로드 실패: {e}")
        return

    if df.empty or 'pkfc_Available_ParkingLots_total' not in df.columns:
        print("유효 분석 데이터 부족으로 프로세스 강제 종료")
        return
        
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df.set_index('timestamp', inplace=True)
    df.sort_index(inplace=True)
    
    df['pkfc_Available_ParkingLots_total'] = df['pkfc_Available_ParkingLots_total'].interpolate(method='linear')
    
    try:
        adf_res = adfuller(df['pkfc_Available_ParkingLots_total'])
        print(f"ADF 통계량 p-value: {adf_res[1]}")
    except Exception as e:
        print(f"정상성 검정 스킵: {e}")
    
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
    df[f_cols] = scaler.fit_transform(df[f_cols])
    
    border = int(len(df) * 0.8)
    if border == 0:
        print("훈련 데이터셋 크기 부족")
        return
        
    train, test = df.iloc[:border], df.iloc[border:]
    
    model = LinearRegression()
    model.fit(train[f_cols], train['pkfc_Available_ParkingLots_total'])
    
    predictions = model.predict(test[f_cols])
    test['preds'] = predictions
    
    mse = np.mean((test['pkfc_Available_ParkingLots_total'] - test['preds']) ** 2)
    mae = np.mean(np.abs(test['pkfc_Available_ParkingLots_total'] - test['preds']))
    print(f"최종 성능 지표 - MSE: {mse}, MAE: {mae}")
    
    plt.figure(figsize=(12, 6))
    plt.plot(test.index, test['pkfc_Available_ParkingLots_total'], label='Real')
    plt.plot(test.index, test['preds'], label='Predict')
    plt.legend()
    plt.savefig('parking_demand_result.png')
    print("[분석 결과] 시각화 이미지 출력 파일 저장 완료")

analyze_parking_demand()