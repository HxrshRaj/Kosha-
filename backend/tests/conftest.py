import os
import tempfile

import pytest

# Must happen before `app.database` (and therefore `app.main`) is imported,
# since the engine is created at module import time from this env var —
# this keeps tests off the real backend/kosha.db file.
_tmp_dir = tempfile.mkdtemp(prefix="kosha_test_")
os.environ["DATABASE_URL"] = f"sqlite:///{_tmp_dir}/test.db"

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c
