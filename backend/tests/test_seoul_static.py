from datetime import datetime, timezone
from contextlib import closing
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import Mock, patch

from pubpark.collectors.seoul_static import (
    CollectionError, fetch_parking_lots, geocode_address, refresh, request_json,
)

NOW = datetime(2026, 11, 10, tzinfo=timezone.utc)
ROW = {"PKLT_CD": "001", "PKLT_NM": "테스트", "ADDR": "종로구 세종로 80-1",
       "TPKCT": "100", "WD_OPER_BGNG_TM": "0000", "BUS_BSC_PRK_CRG": "999",
       "BUS_NEW": "999", "NOW_PRK_VHCL_CNT": "123", "PRK_STTS_YN": "1"}
GEO = {"latitude": 37.57, "longitude": 126.98, "geocode_status": "ok"}


class RefreshTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Path(self.temp.name) / "static.sqlite3"

    def run_refresh(self, **kwargs):
        return refresh(self.db, Mock(), "key", "id", "secret", now=kwargs.pop("now", NOW), **kwargs)

    @patch("pubpark.collectors.seoul_static.geocode_address", return_value=GEO.copy())
    @patch("pubpark.collectors.seoul_static.fetch_parking_lots", return_value=[ROW])
    def test_korean_calendar_month_rollover_updates_and_reuses_coordinates(self, fetch, geo):
        self.run_refresh()
        # November 30 UTC is already December 1 in Korea.
        boundary = datetime(2026, 11, 30, 16, tzinfo=timezone.utc)
        result = self.run_refresh(now=boundary)
        self.assertEqual(result["month"], "2026-12")
        self.assertEqual(result["status"], "updated")
        self.assertEqual(fetch.call_count, 2)
        self.assertEqual(geo.call_count, 1)

    @patch("pubpark.collectors.seoul_static.geocode_address", return_value=GEO.copy())
    @patch("pubpark.collectors.seoul_static.fetch_parking_lots", return_value=[ROW])
    def test_static_only_and_monthly_idempotency(self, fetch, geo):
        result = self.run_refresh()
        self.assertEqual(result["geocoded"], 1)
        with closing(sqlite3.connect(self.db)) as connection:
            row = connection.execute("SELECT static_json, latitude, longitude FROM parking_lots").fetchone()
        fields = json.loads(row[0])
        self.assertFalse(any(key.startswith("BUS_") for key in fields))
        self.assertNotIn("NOW_PRK_VHCL_CNT", fields)
        self.assertNotIn("PRK_STTS_YN", fields)
        self.assertEqual(fields["WD_OPER_BGNG_TM"], "0000")
        self.assertEqual(row[1:], (37.57, 126.98))
        self.assertEqual(self.run_refresh()["status"], "skipped")
        self.assertEqual(fetch.call_count, 1)
        self.assertEqual(geo.call_count, 1)
        self.assertEqual(self.run_refresh(force=True)["reused_coordinates"], 1)
        self.assertEqual(geo.call_count, 1)

    @patch("pubpark.collectors.seoul_static.geocode_address", return_value=GEO.copy())
    @patch("pubpark.collectors.seoul_static.fetch_parking_lots", return_value=[ROW])
    def test_failed_update_rolls_back_and_address_change_regeocodes(self, fetch, geo):
        self.run_refresh()
        fetch.return_value = [{**ROW, "ADDR": "새 주소"}]
        geo.side_effect = CollectionError("failure")
        with self.assertRaises(CollectionError):
            self.run_refresh(force=True)
        with closing(sqlite3.connect(self.db)) as connection:
            old = json.loads(connection.execute("SELECT static_json FROM parking_lots").fetchone()[0])
        self.assertEqual(old["ADDR"], ROW["ADDR"])
        self.assertEqual(geo.call_count, 2)

    @patch("pubpark.collectors.seoul_static.geocode_address", return_value={"latitude": None, "longitude": None, "geocode_status": "no_match"})
    @patch("pubpark.collectors.seoul_static.fetch_parking_lots", return_value=[ROW])
    def test_unresolved_coordinates_are_null(self, fetch, geo):
        self.assertEqual(self.run_refresh()["unresolved"], 1)
        with closing(sqlite3.connect(self.db)) as connection:
            self.assertEqual(connection.execute("SELECT latitude, longitude FROM parking_lots").fetchone(), (None, None))


class ApiTests(unittest.TestCase):
    @patch("pubpark.collectors.seoul_static.request_json")
    def test_pagination_and_duplicate_validation(self, request):
        def response(rows, count):
            return {"GetParkingInfo": {"RESULT": {"CODE": "INFO-000"}, "list_total_count": count, "row": rows}}
        rows = [{"PKLT_CD": str(i)} for i in range(1001)]
        request.side_effect = [response(rows[:1000], 1001), response(rows[1000:], 1001)]
        self.assertEqual(len(fetch_parking_lots(Mock(), "secret")), 1001)
        request.side_effect = None
        request.return_value = response([ROW, ROW], 2)
        with self.assertRaises(CollectionError):
            fetch_parking_lots(Mock(), "secret")

    @patch("pubpark.collectors.seoul_static.request_json")
    def test_geocoding_coordinates_ambiguity_and_no_match(self, request):
        request.return_value = {"status": "OK", "addresses": [{"x": "126.98", "y": "37.57"}]}
        result = geocode_address(Mock(), ROW["ADDR"], "id", "secret")
        self.assertEqual((result["latitude"], result["longitude"]), (37.57, 126.98))
        self.assertTrue(request.call_args.kwargs["params"]["query"].startswith("서울특별시"))
        request.return_value = {"status": "OK", "addresses": [{}, {}]}
        self.assertEqual(geocode_address(Mock(), "주소", "id", "secret")["geocode_status"], "ambiguous")
        request.return_value = {"status": "OK", "addresses": []}
        self.assertEqual(geocode_address(Mock(), "주소", "id", "secret")["geocode_status"], "no_match")

    def test_auth_error_is_not_retried_or_exposed(self):
        session = Mock()
        session.get.return_value.status_code = 401
        with self.assertRaises(CollectionError) as error:
            request_json(session, "https://example.test/secret")
        self.assertNotIn("secret", str(error.exception))
        self.assertEqual(session.get.call_count, 1)


if __name__ == "__main__":
    unittest.main()
