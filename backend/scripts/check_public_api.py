"""Manual connection check; first install backend with pip install -e ."""
from pubpark.collectors.public_data import check_api

if __name__ == "__main__":
    check_api()
