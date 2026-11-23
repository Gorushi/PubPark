"""Environment settings; import performs no I/O."""
import os
from pathlib import Path

DEFAULT_DATA_DIR = Path(__file__).resolve().parents[2] / "data"


def load_local_env():
    """Load backend/.env explicitly; shell environment takes precedence."""
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parents[2] / ".env", override=False)


def required_env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"{name} 환경변수를 설정하세요.")
    return value


def data_dir():
    return Path(os.environ.get("PUBPARK_DATA_DIR") or DEFAULT_DATA_DIR).expanduser().resolve()


def public_data_api_key():
    key = os.environ.get("PUBLIC_DATA_API_KEY", "").strip()
    if not key:
        raise ValueError("PUBLIC_DATA_API_KEY 환경변수를 설정하세요.")
    return key
