import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import StandardScaler
from statsmodels.tsa.stattools import adfuller

CACHE_FILE = 'parking_cache.json'

def analyze_parking_demand():
    print("[시계열 분석] 파이프라인 가동")
    
def analyze_parking_demand():
    print("[시계열 분석] 파이프라인 가동")
    
    # 딕셔너리 구조를 시계열 데이터프레임으로 변환하는 로직
    df = pd.read_json(CACHE_FILE).T