import csv
import os
import pkg_resources
import pg_geocoder.db as db


def extractLikely (rows):
    # Simplest possible method of ranking
    # Number of alternatenames is a rough 
    # measure of importance
    try:
        return max(rows, key=lambda x: len(x.alternatenames))
    except:
        return None

class Extractor (object):
    def _dataPath (self, name):
        DATA_PATH = pkg_resources.resource_filename('pg_geocoder', 'data/')
        return os.path.join(DATA_PATH, name)

    def __init__ (self, db):

        self._db = db 
        self._country_lut = {}

        self._demonyms = {}
        with open(self._dataPath("demonyms.csv"), 'r') as f:
            reader = csv.reader(f)
            self._demonyms = {row[0] : row[1] for row in reader}

        self._country_lut = {}
        with open(self._dataPath("country_codes.csv"), 'r') as f:
            reader = csv.reader(f)
            self._country_lut = {row[0] : row[1] for row in reader}

    def queryPlace (self, name, country = None):
        res = self._db.queryPlaceFuzzy(name)
        if country:
            # potentially convert demonym to country
            country = self._demonyms.get(country, country)
            
            ccode = self._country_lut.get(country,None)
            if not ccode:
                cnt = extractLikely(self._db.queryCountryFuzzy(country))
                if cnt:
                    self._country_lut[cnt.name] = cnt.country
                    self._country_lut[country] = cnt.country
                    ccode = cnt.country
            res = filter(lambda x: x.country == ccode, res)
        return res
            
            






