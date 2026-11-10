from contextlib import closing
from datetime import datetime
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import Mock

from pubpark.api import ParkingApplication, availability, distance_m, is_bus_only
from pubpark.collectors.seoul_static import CollectionError, KST


class AvailabilityTests(unittest.TestCase):
    def test_bus_only_category_and_name_variants(self):
        self.assertTrue(is_bus_only({'OPER_SE_NM':'버스전용 주차장'}))
        self.assertTrue(is_bus_only({'PKLT_NM':'훈련원공원 앞 관광버스 전용 주차장(시)'}))
        self.assertFalse(is_bus_only({'PKLT_NM':'일반 공영주차장', 'BUS_BSC_PRK_CRG':'1000'}))

    def test_invalid_observations_are_unknown_not_empty(self):
        now = datetime(2026,11,10,9,tzinfo=KST)
        base = {'PRK_STTS_YN':'1','NOW_PRK_VHCL_UPDT_TM':'2026-11-10 08:59:00','NOW_PRK_VHCL_CNT':'58'}
        self.assertEqual(availability(base,100,now)[0],42)
        self.assertEqual(availability({**base,'NOW_PRK_VHCL_CNT':'101'},100,now)[1],'inconsistent')
        self.assertIsNone(availability({**base,'PRK_STTS_YN':'0'},100,now)[0])
        self.assertEqual(availability({**base,'NOW_PRK_VHCL_UPDT_TM':'2026-11-10 08:00:00'},100,now)[1],'stale')
        self.assertEqual(availability({**base,'NOW_PRK_VHCL_CNT':'100'},100,now)[0],0)

    def test_nearest_ten_and_provider_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            db=Path(directory)/'static.sqlite3'
            with closing(sqlite3.connect(db)) as c, c:
                c.execute('CREATE TABLE parking_lots (id TEXT,static_json TEXT,latitude REAL,longitude REAL,geocode_status TEXT)')
                c.execute('INSERT INTO parking_lots VALUES (?,?,?,?,?)',('bus',json.dumps({'PKLT_NM':'관광버스 전용 주차장','TPKCT':'50'}),37.56,126.97,'ok'))
                for i in range(12):
                    c.execute('INSERT INTO parking_lots VALUES (?,?,?,?,?)',(str(i),json.dumps({'TPKCT':'100','PKLT_NM':str(i),'ADDR':'address'}),37.56+i*.001,126.97,'ok'))
            app=ParkingApplication(db,'key','id','secret')
            app.live_rows=Mock(side_effect=CollectionError('offline'))
            result=app.nearby({'latitude':37.56,'longitude':126.97,'name':'goal'})
            self.assertEqual(len(result['parkings']),10)
            self.assertEqual(result['parkings'][0]['id'],'0')
            self.assertNotIn('bus',[p['id'] for p in result['parkings']])
            self.assertTrue(all(p['available_spaces'] is None for p in result['parkings']))
            self.assertTrue(result['notice'])

    def test_distance_is_symmetric(self):
        a={'latitude':37.56,'longitude':126.97}
        b={'latitude':37.57,'longitude':126.98}
        self.assertAlmostEqual(distance_m(a,b),distance_m(b,a))
        self.assertEqual(distance_m(a,a),0)


if __name__=='__main__':
    unittest.main()
