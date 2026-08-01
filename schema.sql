-- GVMC Change-Detection Engine — schema + seed data
-- MySQL 8, InnoDB, utf8mb4
-- Seed data mirrors frontend/src/mocks/data/{wards,properties,alerts}.js exactly
-- (same ids/coords/statuses) so the real API produces results consistent with
-- what the frontend was built and demoed against.

SET NAMES utf8mb4;

-- Re-runnable from Workbench: always reset to a clean schema matching the
-- CREATE TABLEs below, instead of silently keeping stale columns/rows from
-- an earlier run of an older version of this file.
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS properties, alerts, admin_config, wards;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE IF NOT EXISTS wards (
  id          CHAR(8)      NOT NULL PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  zone        VARCHAR(50)  NULL,
  pincode     CHAR(6)      NULL,
  bbox_north  DECIMAL(9,6) NOT NULL,
  bbox_south  DECIMAL(9,6) NOT NULL,
  bbox_east   DECIMAL(9,6) NOT NULL,
  bbox_west   DECIMAL(9,6) NOT NULL,
  geojson_s3  VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- `zone`/`pincode` and every column below from `address` through `owner_name`
-- match frontend/src/mockData/gvmc_properties_mock.csv (bulk CSV import
-- format); `baseline_year`/`comparison_year` are the satellite comparison
-- pair used by the "from year -> to year" filter (see indexes below).
CREATE TABLE IF NOT EXISTS properties (
  id                       VARCHAR(36)  NOT NULL PRIMARY KEY,
  ward_id                  CHAR(8)      NOT NULL,
  lat                      DECIMAL(9,6) NOT NULL,
  lng                      DECIMAL(9,6) NOT NULL,
  address                  VARCHAR(150) NULL,
  pincode                  CHAR(6)      NULL,
  property_type            ENUM('Residential','Commercial','Mixed Use','Industrial','Vacant Land') NULL,
  area_sqm                 INT          NOT NULL,
  detection_type           ENUM('new_build','change_of_use') NOT NULL,
  confidence               DECIMAL(3,2) NOT NULL,
  confidence_breakdown     JSON         NULL,
  ndbi_delta               DECIMAL(3,2) NULL,
  area_delta               DECIMAL(3,2) NULL,
  ndvi_drop                DECIMAL(3,2) NULL,
  osm_status               DECIMAL(3,2) NULL,
  db_match                 DECIMAL(3,2) NULL,
  baseline_year            SMALLINT UNSIGNED NULL,
  comparison_year          SMALLINT UNSIGNED NULL,
  detected_at              DATETIME     NOT NULL,
  s3_geojson_key           VARCHAR(255) NULL,
  status                   ENUM('pending','verified','underassessed','false_positive','already_assessed') NOT NULL DEFAULT 'pending',
  estimated_annual_tax_inr INT UNSIGNED NULL,
  owner_name               VARCHAR(60)  NULL,
  notes                    TEXT         NULL,
  updated_by               VARCHAR(100) NULL,
  updated_at               DATETIME     NULL,
  ai_explanation           TEXT         NULL,
  CONSTRAINT fk_properties_ward FOREIGN KEY (ward_id) REFERENCES wards(id),
  CONSTRAINT chk_properties_year_order CHECK (baseline_year IS NULL OR comparison_year IS NULL OR comparison_year >= baseline_year),
  INDEX idx_properties_ward (ward_id),
  INDEX idx_properties_ward_type (ward_id, detection_type),
  INDEX idx_properties_ward_status (ward_id, status),
  INDEX idx_properties_years (baseline_year, comparison_year),
  INDEX idx_properties_ward_years (ward_id, baseline_year, comparison_year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS alerts (
  id          VARCHAR(36) NOT NULL PRIMARY KEY,
  ward_id     CHAR(8)     NOT NULL,
  severity    ENUM('info','warning','danger') NOT NULL,
  text        TEXT        NOT NULL,
  created_at  DATETIME    NOT NULL,
  CONSTRAINT fk_alerts_ward FOREIGN KEY (ward_id) REFERENCES wards(id),
  INDEX idx_alerts_ward (ward_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS admin_config (
  key_name  VARCHAR(50)  NOT NULL PRIMARY KEY,
  value     TEXT         NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =========================================================================
-- SEED DATA
-- =========================================================================

-- All 98 real GVMC wards, generated from frontend/src/mockData/gvmc_wards_reference.csv
-- (ids match that CSV and gvmc_properties_mock.csv's ward_id column exactly, so the
-- mock properties CSV can be uploaded via /api/admin/upload-csv with no remapping).
-- zone/pincode are the same "plausible, not surveyed" approximation described in
-- frontend/src/mockData/README.md, not an official GVMC ward-to-zone mapping.
INSERT INTO wards (id, name, zone, pincode, bbox_north, bbox_south, bbox_east, bbox_west, geojson_s3) VALUES
('1', 'Bheemunipatnam', 'Bheemunipatnam', '530001', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-1.json'),
('2', 'Madhurawada', 'Madhurawada', '530009', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-2.json'),
('3', 'Asilmetta', 'Asilmetta', '530017', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-3.json'),
('4', 'Suryabagh', 'Suryabagh', '530020', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-4.json'),
('5', 'Gnanapuram', 'Gnanapuram', '530030', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-5.json'),
('6', 'Gajuwaka', 'Gajuwaka', '530035', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-6.json'),
('7', 'Anakapalli', 'Anakapalli', '530040', 17.65, 17.58, 83.1, 83, 'geojson/ward-7.json'),
('8', 'Vepagunta', 'Vepagunta', '530043', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-8.json'),
('9', 'Sagar Nagar', 'Bheemunipatnam', '530006', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-9.json'),
('10', 'Pendurthi', 'Madhurawada', '530008', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-10.json'),
('11', 'Dwaraka Nagar', 'Asilmetta', '530014', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-11.json'),
('12', 'Jagadamba Junction', 'Suryabagh', '530024', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-12.json'),
('13', 'NAD Junction', 'Gnanapuram', '530030', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-13.json'),
('14', 'Kurmannapalem', 'Gajuwaka', '530032', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-14.json'),
('15', 'Sabbavaram', 'Anakapalli', '530040', 17.65, 17.58, 83.1, 83, 'geojson/ward-15.json'),
('16', 'Simhachalam', 'Vepagunta', '530044', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-16.json'),
('17', 'Rushikonda', 'Bheemunipatnam', '530004', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-17.json'),
('18', 'Marikavalasa', 'Madhurawada', '530007', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-18.json'),
('19', 'Siripuram', 'Asilmetta', '530013', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-19.json'),
('20', 'One Town', 'Suryabagh', '530024', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-20.json'),
('21', 'Malkapuram', 'Gnanapuram', '530030', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-21.json'),
('22', 'Autonagar', 'Gajuwaka', '530035', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-22.json'),
('23', 'Butchayyapeta', 'Anakapalli', '530040', 17.65, 17.58, 83.1, 83, 'geojson/ward-23.json'),
('24', 'Adavivaram', 'Vepagunta', '530046', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-24.json'),
('25', 'Anandapuram', 'Bheemunipatnam', '530005', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-25.json'),
('26', 'Sujatha Nagar', 'Madhurawada', '530008', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-26.json'),
('27', 'MVP Colony', 'Asilmetta', '530013', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-27.json'),
('28', 'Poorna Market', 'Suryabagh', '530024', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-28.json'),
('29', 'Kancharapalem', 'Gnanapuram', '530027', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-29.json'),
('30', 'BHPV Colony', 'Gajuwaka', '530035', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-30.json'),
('31', 'Kasimkota', 'Anakapalli', '530039', 17.65, 17.58, 83.1, 83, 'geojson/ward-31.json'),
('32', 'Vepagunta Colony', 'Vepagunta', '530046', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-32.json'),
('33', 'Padmanabham', 'Bheemunipatnam', '530002', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-33.json'),
('34', 'Kommadi', 'Madhurawada', '530012', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-34.json'),
('35', 'Seethammadhara', 'Asilmetta', '530016', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-35.json'),
('36', 'Kotha Road', 'Suryabagh', '530024', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-36.json'),
('37', 'Marripalem', 'Gnanapuram', '530026', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-37.json'),
('38', 'Aganampudi', 'Gajuwaka', '530031', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-38.json'),
('39', 'Yeleswaram', 'Anakapalli', '530040', 17.65, 17.58, 83.1, 83, 'geojson/ward-39.json'),
('40', 'Vepagunta (Ward 40)', 'Vepagunta', '530046', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-40.json'),
('41', 'Kapuluppada', 'Bheemunipatnam', '530006', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-41.json'),
('42', 'PM Palem', 'Madhurawada', '530007', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-42.json'),
('43', 'Maddilapalem', 'Asilmetta', '530015', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-43.json'),
('44', 'Old Town', 'Suryabagh', '530022', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-44.json'),
('45', 'Gopalapatnam', 'Gnanapuram', '530028', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-45.json'),
('46', 'Naidupalem', 'Gajuwaka', '530035', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-46.json'),
('47', 'Anakapalli (Ward 47)', 'Anakapalli', '530037', 17.65, 17.58, 83.1, 83, 'geojson/ward-47.json'),
('48', 'Simhachalam (Ward 48)', 'Vepagunta', '530046', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-48.json'),
('49', 'Bheemunipatnam (Ward 49)', 'Bheemunipatnam', '530003', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-49.json'),
('50', 'Yendada', 'Madhurawada', '530009', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-50.json'),
('51', 'Chinna Waltair', 'Asilmetta', '530016', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-51.json'),
('52', 'Suryabagh (Ward 52)', 'Suryabagh', '530023', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-52.json'),
('53', 'Pedagantyada', 'Gnanapuram', '530029', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-53.json'),
('54', 'New Gajuwaka', 'Gajuwaka', '530032', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-54.json'),
('55', 'Sabbavaram (Ward 55)', 'Anakapalli', '530042', 17.65, 17.58, 83.1, 83, 'geojson/ward-55.json'),
('56', 'Adavivaram (Ward 56)', 'Vepagunta', '530047', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-56.json'),
('57', 'Sagar Nagar (Ward 57)', 'Bheemunipatnam', '530003', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-57.json'),
('58', 'Madhurawada (Ward 58)', 'Madhurawada', '530010', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-58.json'),
('59', 'Daba Gardens', 'Asilmetta', '530018', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-59.json'),
('60', 'Jagadamba Junction (Ward 60)', 'Suryabagh', '530021', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-60.json'),
('61', 'Gnanapuram (Ward 61)', 'Gnanapuram', '530025', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-61.json'),
('62', 'Gajuwaka (Ward 62)', 'Gajuwaka', '530036', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-62.json'),
('63', 'Butchayyapeta (Ward 63)', 'Anakapalli', '530040', 17.65, 17.58, 83.1, 83, 'geojson/ward-63.json'),
('64', 'Vepagunta Colony (Ward 64)', 'Vepagunta', '530043', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-64.json'),
('65', 'Rushikonda (Ward 65)', 'Bheemunipatnam', '530005', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-65.json'),
('66', 'Pendurthi (Ward 66)', 'Madhurawada', '530009', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-66.json'),
('67', 'Asilmetta (Ward 67)', 'Asilmetta', '530018', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-67.json'),
('68', 'One Town (Ward 68)', 'Suryabagh', '530022', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-68.json'),
('69', 'NAD Junction (Ward 69)', 'Gnanapuram', '530026', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-69.json'),
('70', 'Kurmannapalem (Ward 70)', 'Gajuwaka', '530035', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-70.json'),
('71', 'Kasimkota (Ward 71)', 'Anakapalli', '530039', 17.65, 17.58, 83.1, 83, 'geojson/ward-71.json'),
('72', 'Vepagunta (Ward 72)', 'Vepagunta', '530044', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-72.json'),
('73', 'Anandapuram (Ward 73)', 'Bheemunipatnam', '530004', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-73.json'),
('74', 'Marikavalasa (Ward 74)', 'Madhurawada', '530009', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-74.json'),
('75', 'Dwaraka Nagar (Ward 75)', 'Asilmetta', '530014', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-75.json'),
('76', 'Poorna Market (Ward 76)', 'Suryabagh', '530022', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-76.json'),
('77', 'Malkapuram (Ward 77)', 'Gnanapuram', '530026', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-77.json'),
('78', 'Autonagar (Ward 78)', 'Gajuwaka', '530031', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-78.json'),
('79', 'Yeleswaram (Ward 79)', 'Anakapalli', '530037', 17.65, 17.58, 83.1, 83, 'geojson/ward-79.json'),
('80', 'Simhachalam (Ward 80)', 'Vepagunta', '530043', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-80.json'),
('81', 'Padmanabham (Ward 81)', 'Bheemunipatnam', '530006', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-81.json'),
('82', 'Sujatha Nagar (Ward 82)', 'Madhurawada', '530011', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-82.json'),
('83', 'Siripuram (Ward 83)', 'Asilmetta', '530014', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-83.json'),
('84', 'Kotha Road (Ward 84)', 'Suryabagh', '530020', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-84.json'),
('85', 'Kancharapalem (Ward 85)', 'Gnanapuram', '530028', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-85.json'),
('86', 'BHPV Colony (Ward 86)', 'Gajuwaka', '530033', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-86.json'),
('87', 'Anakapalli (Ward 87)', 'Anakapalli', '530039', 17.65, 17.58, 83.1, 83, 'geojson/ward-87.json'),
('88', 'Adavivaram (Ward 88)', 'Vepagunta', '530048', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-88.json'),
('89', 'Kapuluppada (Ward 89)', 'Bheemunipatnam', '530004', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-89.json'),
('90', 'Kommadi (Ward 90)', 'Madhurawada', '530010', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-90.json'),
('91', 'MVP Colony (Ward 91)', 'Asilmetta', '530016', 17.745, 17.7, 83.33, 83.29, 'geojson/ward-91.json'),
('92', 'Old Town (Ward 92)', 'Suryabagh', '530020', 17.715, 17.685, 83.31, 83.28, 'geojson/ward-92.json'),
('93', 'Marripalem (Ward 93)', 'Gnanapuram', '530028', 17.7, 17.66, 83.29, 83.24, 'geojson/ward-93.json'),
('94', 'Aganampudi (Ward 94)', 'Gajuwaka', '530035', 17.68, 17.64, 83.24, 83.19, 'geojson/ward-94.json'),
('95', 'Sabbavaram (Ward 95)', 'Anakapalli', '530040', 17.65, 17.58, 83.1, 83, 'geojson/ward-95.json'),
('96', 'Vepagunta Colony (Ward 96)', 'Vepagunta', '530044', 17.775, 17.74, 83.28, 83.23, 'geojson/ward-96.json'),
('97', 'Bheemunipatnam (Ward 97)', 'Bheemunipatnam', '530006', 17.895, 17.78, 83.46, 83.37, 'geojson/ward-97.json'),
('98', 'PM Palem (Ward 98)', 'Madhurawada', '530011', 17.82, 17.76, 83.38, 83.3, 'geojson/ward-98.json');

-- Small curated set on the real wards 1-3 (Bheemunipatnam, Madhurawada,
-- Asilmetta) with deliberately varied baseline/comparison year pairs, so the
-- year-picker and NDBI heatmap have multi-year data to test immediately —
-- the bulk gvmc_properties_mock.csv (all 98 wards) is fixed to a single
-- 2022/2024 pair for every row, so this fills that gap for wards 1-3.
INSERT INTO properties
  (id, ward_id, lat, lng, area_sqm, detection_type, confidence, confidence_breakdown, ndbi_delta, baseline_year, comparison_year, detected_at, s3_geojson_key, status, ai_explanation, updated_by, updated_at)
VALUES
('prop-w1-001', '1', 17.85, 83.42, 320, 'new_build', 0.92, '{"ndbi_delta": 0.91, "area_delta": 0.83, "osm_status": 0.75, "ndvi_drop": 0.85, "db_match": 0.77}', 0.91, 2022, 2024, '2026-07-17 00:00:00', 'geojson/ward-1/prop-w1-001.json', 'pending', NULL, NULL, NULL),
('prop-w1-002', '1', 17.83, 83.40, 190, 'change_of_use', 0.74, '{"ndbi_delta": 0.66, "area_delta": 0.57, "osm_status": 0.48, "ndvi_drop": 0.6, "db_match": 0.51}', 0.66, 2024, 2026, '2026-07-10 00:00:00', 'geojson/ward-1/prop-w1-002.json', 'verified', '**Analysis for property prop-w1-002**: This property scores 74% confidence for change of use.\n\nNDBI delta (66%) indicates significant built-up area increase between 2024 and 2026 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-07-10 00:00:00'),
('prop-w1-003', '1', 17.81, 83.44, 450, 'new_build', 0.87, '{"ndbi_delta": 0.79, "area_delta": 0.69, "osm_status": 0.59, "ndvi_drop": 0.73, "db_match": 0.62}', 0.79, 2022, 2026, '2026-07-19 00:00:00', 'geojson/ward-1/prop-w1-003.json', 'pending', NULL, NULL, NULL),
('prop-w1-004', '1', 17.86, 83.38, 220, 'change_of_use', 0.61, '{"ndbi_delta": 0.56, "area_delta": 0.48, "osm_status": 0.41, "ndvi_drop": 0.51, "db_match": 0.43}', 0.56, 2022, 2024, '2026-07-05 00:00:00', 'geojson/ward-1/prop-w1-004.json', 'false_positive', '**Analysis for property prop-w1-004**: This property scores 61% confidence for change of use.\n\nNDBI delta (56%) indicates a modest built-up area increase between 2022 and 2024 satellite passes.\n\n**Recommendation**: Low priority — monitor next cycle.', 'system', '2026-07-05 00:00:00'),
('prop-w2-001', '2', 17.79, 83.34, 400, 'new_build', 0.88, '{"ndbi_delta": 0.87, "area_delta": 0.8, "osm_status": 0.72, "ndvi_drop": 0.81, "db_match": 0.74}', 0.87, 2022, 2024, '2026-07-15 00:00:00', 'geojson/ward-2/prop-w2-001.json', 'pending', NULL, NULL, NULL),
('prop-w2-002', '2', 17.77, 83.36, 175, 'change_of_use', 0.7, '{"ndbi_delta": 0.62, "area_delta": 0.53, "osm_status": 0.45, "ndvi_drop": 0.57, "db_match": 0.48}', 0.62, 2024, 2026, '2026-07-08 00:00:00', 'geojson/ward-2/prop-w2-002.json', 'verified', '**Analysis for property prop-w2-002**: This property scores 70% confidence for change of use.\n\nNDBI delta (62%) indicates significant built-up area increase between 2024 and 2026 satellite passes.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-07-08 00:00:00'),
('prop-w2-003', '2', 17.80, 83.32, 610, 'new_build', 0.91, '{"ndbi_delta": 0.85, "area_delta": 0.75, "osm_status": 0.65, "ndvi_drop": 0.78, "db_match": 0.68}', 0.85, 2022, 2026, '2026-07-11 00:00:00', 'geojson/ward-2/prop-w2-003.json', 'underassessed', '**Analysis for property prop-w2-003**: This property scores 91% confidence for new construction.\n\nNDBI delta (85%) indicates significant built-up area increase between 2022 and 2026 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: High priority — schedule field verification within 7 days.', 'system', '2026-07-11 00:00:00'),
('prop-w2-004', '2', 17.78, 83.35, 250, 'change_of_use', 0.66, '{"ndbi_delta": 0.62, "area_delta": 0.55, "osm_status": 0.48, "ndvi_drop": 0.57, "db_match": 0.5}', 0.62, 2022, 2024, '2026-07-18 00:00:00', 'geojson/ward-2/prop-w2-004.json', 'pending', NULL, NULL, NULL),
('prop-w3-001', '3', 17.72, 83.31, 355, 'new_build', 0.77, '{"ndbi_delta": 0.76, "area_delta": 0.7, "osm_status": 0.64, "ndvi_drop": 0.72, "db_match": 0.66}', 0.76, 2022, 2024, '2026-07-16 00:00:00', 'geojson/ward-3/prop-w3-001.json', 'pending', NULL, NULL, NULL),
('prop-w3-002', '3', 17.71, 83.305, 430, 'change_of_use', 0.89, '{"ndbi_delta": 0.81, "area_delta": 0.7, "osm_status": 0.59, "ndvi_drop": 0.73, "db_match": 0.62}', 0.81, 2024, 2026, '2026-07-06 00:00:00', 'geojson/ward-3/prop-w3-002.json', 'verified', '**Analysis for property prop-w3-002**: This property scores 89% confidence for change of use.\n\nNDBI delta (81%) indicates significant built-up area increase between 2024 and 2026 satellite passes.\n\n**Recommendation**: High priority — schedule field verification within 7 days.', 'system', '2026-07-06 00:00:00'),
('prop-w3-003', '3', 17.735, 83.32, 200, 'new_build', 0.53, '{"ndbi_delta": 0.47, "area_delta": 0.4, "osm_status": 0.34, "ndvi_drop": 0.43, "db_match": 0.36}', 0.47, 2022, 2026, '2026-07-19 00:00:00', 'geojson/ward-3/prop-w3-003.json', 'pending', NULL, NULL, NULL),
('prop-w3-004', '3', 17.705, 83.295, 335, 'change_of_use', 0.72, '{"ndbi_delta": 0.66, "area_delta": 0.58, "osm_status": 0.5, "ndvi_drop": 0.6, "db_match": 0.52}', 0.66, 2022, 2024, '2026-06-28 00:00:00', 'geojson/ward-3/prop-w3-004.json', 'already_assessed', '**Analysis for property prop-w3-004**: This property scores 72% confidence for change of use.\n\nNDBI delta (66%) indicates significant built-up area increase between 2022 and 2024 satellite passes.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-06-28 00:00:00');

INSERT INTO alerts (id, ward_id, severity, text, created_at) VALUES
('alt-w1-1', '1', 'danger',  '8 high-confidence detections (>85%) in Bheemunipatnam sector B. Immediate field verification recommended before quarterly assessment deadline.', '2026-07-29 06:00:00'),
('alt-w1-2', '1', 'warning', 'Revenue leakage estimate for ward: ₹12.4L/year based on 3 underassessed commercial conversions on Nowroji Road.', '2026-07-28 14:00:00'),
('alt-w1-3', '1', 'info',    'Pipeline last run completed successfully. 34 change polygons loaded. Next scheduled run: 01 Aug 2026.', '2026-07-27 20:00:00'),
('alt-w2-1', '2', 'warning', '3 properties near RK Beach Road show commercial activity without updated property tax classification.', '2026-07-29 03:00:00'),
('alt-w2-2', '2', 'info',    'Low NDVI detected across 4 parcels — potential paving over green areas for parking. Confidence avg: 70%.', '2026-07-28 08:00:00'),
('alt-w3-1', '3', 'info',    'Routine scan complete. 2 new build detections added to queue. No high-severity anomalies.', '2026-07-27 00:00:00'),
('alt-w4-1', '4', 'danger',  'CRITICAL: 4 multi-story buildings detected in Suryabagh without corresponding building permits. Estimated annual revenue gap: ₹31.8L.', '2026-07-29 07:00:00'),
('alt-w4-2', '4', 'danger',  '2 properties reclassified from residential to commercial use without notification to assessment office.', '2026-07-29 00:00:00'),
('alt-w4-3', '4', 'warning', 'NDBI delta spike (avg 0.31) across Suryabagh Junction — bulk construction suggests multi-unit residential project.', '2026-07-28 10:00:00'),
('alt-w5-1', '5', 'warning', 'A high-confidence (91%) change-of-use detection near Gnanapuram circle suggests a hospitality / serviced apartment conversion.', '2026-07-28 18:00:00'),
('alt-w5-2', '5', 'info',    '4 detections verified as false positives (reflective rooftop solar panels). Model refinement queued.', '2026-07-26 12:00:00');

INSERT INTO admin_config (key_name, value) VALUES
('data_mode', 'demo'),
('pipeline_status', 'idle'),
('last_refresh', '2026-07-30T04:00:00.000Z'),
('ndbi_threshold', '0.15'),
('ndbi_threshold_high', '0.6'),
('ai_brief', NULL),
('ai_brief_updated_at', NULL);
