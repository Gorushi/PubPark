"""Environment settings; import performs no I/O."""
import os
from pathlib import Path

DEFAULT_DATA_DIR = Path(__file__).resolve().parents[2] / "data"


def data_dir():
    return Path(os.environ.get("PUBPARK_DATA_DIR") or DEFAULT_DATA_DIR).expanduser().resolve()


def public_data_api_key():
    key = os.environ.get("PUBLIC_DATA_API_KEY", "").strip()
    if not key:
        raise ValueError("PUBLIC_DATA_API_KEY 환경변수를 설정하세요.")
    return key
