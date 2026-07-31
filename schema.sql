-- GVMC Change-Detection Engine — schema + seed data
-- MySQL 8, InnoDB, utf8mb4
-- Seed data mirrors frontend/src/mocks/data/{wards,properties,alerts}.js exactly
-- (same ids/coords/statuses) so the real API produces results consistent with
-- what the frontend was built and demoed against.

SET NAMES utf8mb4;

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

INSERT INTO wards (id, name, bbox_north, bbox_south, bbox_east, bbox_west, geojson_s3) VALUES
('1', 'Seethammadhara', 17.745, 17.715, 83.315, 83.280, 'geojson/ward-1.json'),
('2', 'Gopalapatnam',   17.778, 17.748, 83.278, 83.245, 'geojson/ward-2.json'),
('3', 'Maddilapalem',   17.728, 17.700, 83.302, 83.270, 'geojson/ward-3.json'),
('4', 'Asilmetta',      17.710, 17.685, 83.230, 83.200, 'geojson/ward-4.json'),
('5', 'Dwaraka Nagar',  17.695, 17.668, 83.220, 83.190, 'geojson/ward-5.json');

INSERT INTO properties
  (id, ward_id, lat, lng, area_sqm, detection_type, confidence, confidence_breakdown, detected_at, s3_geojson_key, status, ai_explanation, updated_by, updated_at)
VALUES
('prop-w1-001', '1', 17.73, 83.295, 312, 'new_build', 0.92, '{"ndbi_delta": 0.91, "area_delta": 0.83, "osm_status": 0.75, "ndvi_drop": 0.85, "db_match": 0.77}', '2026-07-17 00:00:00', 'geojson/ward-1/prop-w1-001.json', 'pending', NULL, NULL, NULL),
('prop-w1-002', '1', 17.722, 83.301, 188, 'change_of_use', 0.74, '{"ndbi_delta": 0.66, "area_delta": 0.57, "osm_status": 0.48, "ndvi_drop": 0.6, "db_match": 0.51}', '2026-07-10 00:00:00', 'geojson/ward-1/prop-w1-002.json', 'verified', '**Analysis for property prop-w1-002**: This property scores 74% confidence for change of use.\n\nNDBI delta (66%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-07-10 00:00:00'),
('prop-w1-003', '1', 17.735, 83.308, 445, 'new_build', 0.87, '{"ndbi_delta": 0.79, "area_delta": 0.69, "osm_status": 0.59, "ndvi_drop": 0.73, "db_match": 0.62}', '2026-07-19 00:00:00', 'geojson/ward-1/prop-w1-003.json', 'pending', NULL, NULL, NULL),
('prop-w1-004', '1', 17.718, 83.285, 220, 'new_build', 0.61, '{"ndbi_delta": 0.56, "area_delta": 0.48, "osm_status": 0.41, "ndvi_drop": 0.51, "db_match": 0.43}', '2026-07-05 00:00:00', 'geojson/ward-1/prop-w1-004.json', 'false_positive', '**Analysis for property prop-w1-004**: This property scores 61% confidence for new construction.\n\nNDBI delta (56%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-07-05 00:00:00'),
('prop-w1-005', '1', 17.741, 83.291, 567, 'change_of_use', 0.83, '{"ndbi_delta": 0.77, "area_delta": 0.68, "osm_status": 0.59, "ndvi_drop": 0.71, "db_match": 0.62}', '2026-07-14 00:00:00', 'geojson/ward-1/prop-w1-005.json', 'underassessed', '**Analysis for property prop-w1-005**: This property scores 83% confidence for change of use.\n\nNDBI delta (77%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: High priority — schedule field verification within 7 days.', 'system', '2026-07-14 00:00:00'),
('prop-w1-006', '1', 17.724, 83.298, 134, 'new_build', 0.55, '{"ndbi_delta": 0.51, "area_delta": 0.46, "osm_status": 0.4, "ndvi_drop": 0.47, "db_match": 0.42}', '2026-07-18 00:00:00', 'geojson/ward-1/prop-w1-006.json', 'pending', NULL, NULL, NULL),
('prop-w1-007', '1', 17.737, 83.304, 299, 'change_of_use', 0.79, '{"ndbi_delta": 0.75, "area_delta": 0.67, "osm_status": 0.59, "ndvi_drop": 0.7, "db_match": 0.62}', '2026-06-30 00:00:00', 'geojson/ward-1/prop-w1-007.json', 'already_assessed', '**Analysis for property prop-w1-007**: This property scores 79% confidence for change of use.\n\nNDBI delta (75%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-06-30 00:00:00'),
('prop-w1-008', '1', 17.716, 83.289, 680, 'new_build', 0.94, '{"ndbi_delta": 0.9, "area_delta": 0.81, "osm_status": 0.72, "ndvi_drop": 0.84, "db_match": 0.75}', '2026-07-16 00:00:00', 'geojson/ward-1/prop-w1-008.json', 'pending', NULL, NULL, NULL),
('prop-w2-001', '2', 17.762, 83.258, 401, 'new_build', 0.88, '{"ndbi_delta": 0.87, "area_delta": 0.8, "osm_status": 0.72, "ndvi_drop": 0.81, "db_match": 0.74}', '2026-07-15 00:00:00', 'geojson/ward-2/prop-w2-001.json', 'pending', NULL, NULL, NULL),
('prop-w2-002', '2', 17.755, 83.265, 172, 'change_of_use', 0.7, '{"ndbi_delta": 0.62, "area_delta": 0.53, "osm_status": 0.45, "ndvi_drop": 0.57, "db_match": 0.48}', '2026-07-08 00:00:00', 'geojson/ward-2/prop-w2-002.json', 'verified', '**Analysis for property prop-w2-002**: This property scores 70% confidence for change of use.\n\nNDBI delta (62%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-07-08 00:00:00'),
('prop-w2-003', '2', 17.768, 83.27, 290, 'new_build', 0.45, '{"ndbi_delta": 0.4, "area_delta": 0.33, "osm_status": 0.28, "ndvi_drop": 0.36, "db_match": 0.3}', '2026-07-02 00:00:00', 'geojson/ward-2/prop-w2-003.json', 'false_positive', '**Analysis for property prop-w2-003**: This property scores 45% confidence for new construction.\n\nNDBI delta (40%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-07-02 00:00:00'),
('prop-w2-004', '2', 17.751, 83.252, 510, 'change_of_use', 0.82, '{"ndbi_delta": 0.75, "area_delta": 0.66, "osm_status": 0.57, "ndvi_drop": 0.69, "db_match": 0.6}', '2026-07-13 00:00:00', 'geojson/ward-2/prop-w2-004.json', 'pending', NULL, NULL, NULL),
('prop-w2-005', '2', 17.773, 83.262, 623, 'new_build', 0.91, '{"ndbi_delta": 0.85, "area_delta": 0.75, "osm_status": 0.65, "ndvi_drop": 0.78, "db_match": 0.68}', '2026-07-11 00:00:00', 'geojson/ward-2/prop-w2-005.json', 'underassessed', '**Analysis for property prop-w2-005**: This property scores 91% confidence for new construction.\n\nNDBI delta (85%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: High priority — schedule field verification within 7 days.', 'system', '2026-07-11 00:00:00'),
('prop-w2-006', '2', 17.759, 83.256, 245, 'change_of_use', 0.66, '{"ndbi_delta": 0.62, "area_delta": 0.55, "osm_status": 0.48, "ndvi_drop": 0.57, "db_match": 0.5}', '2026-07-18 00:00:00', 'geojson/ward-2/prop-w2-006.json', 'pending', NULL, NULL, NULL),
('prop-w3-001', '3', 17.714, 83.285, 356, 'new_build', 0.77, '{"ndbi_delta": 0.76, "area_delta": 0.7, "osm_status": 0.64, "ndvi_drop": 0.72, "db_match": 0.66}', '2026-07-16 00:00:00', 'geojson/ward-3/prop-w3-001.json', 'pending', NULL, NULL, NULL),
('prop-w3-002', '3', 17.708, 83.292, 428, 'change_of_use', 0.89, '{"ndbi_delta": 0.81, "area_delta": 0.7, "osm_status": 0.59, "ndvi_drop": 0.73, "db_match": 0.62}', '2026-07-06 00:00:00', 'geojson/ward-3/prop-w3-002.json', 'verified', '**Analysis for property prop-w3-002**: This property scores 89% confidence for change of use.\n\nNDBI delta (81%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: High priority — schedule field verification within 7 days.', 'system', '2026-07-06 00:00:00'),
('prop-w3-003', '3', 17.721, 83.279, 198, 'new_build', 0.53, '{"ndbi_delta": 0.47, "area_delta": 0.4, "osm_status": 0.34, "ndvi_drop": 0.43, "db_match": 0.36}', '2026-07-19 00:00:00', 'geojson/ward-3/prop-w3-003.json', 'pending', NULL, NULL, NULL),
('prop-w3-004', '3', 17.704, 83.298, 334, 'change_of_use', 0.72, '{"ndbi_delta": 0.66, "area_delta": 0.58, "osm_status": 0.5, "ndvi_drop": 0.6, "db_match": 0.52}', '2026-06-28 00:00:00', 'geojson/ward-3/prop-w3-004.json', 'already_assessed', '**Analysis for property prop-w3-004**: This property scores 72% confidence for change of use.\n\nNDBI delta (66%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-06-28 00:00:00'),
('prop-w4-001', '4', 17.698, 83.215, 789, 'new_build', 0.96, '{"ndbi_delta": 0.94, "area_delta": 0.86, "osm_status": 0.78, "ndvi_drop": 0.88, "db_match": 0.8}', '2026-07-19 00:00:00', 'geojson/ward-4/prop-w4-001.json', 'pending', NULL, NULL, NULL),
('prop-w4-002', '4', 17.692, 83.221, 267, 'change_of_use', 0.81, '{"ndbi_delta": 0.73, "area_delta": 0.63, "osm_status": 0.53, "ndvi_drop": 0.66, "db_match": 0.56}', '2026-07-09 00:00:00', 'geojson/ward-4/prop-w4-002.json', 'verified', '**Analysis for property prop-w4-002**: This property scores 81% confidence for change of use.\n\nNDBI delta (73%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: High priority — schedule field verification within 7 days.', 'system', '2026-07-09 00:00:00'),
('prop-w4-003', '4', 17.703, 83.208, 412, 'new_build', 0.74, '{"ndbi_delta": 0.67, "area_delta": 0.58, "osm_status": 0.49, "ndvi_drop": 0.61, "db_match": 0.52}', '2026-07-17 00:00:00', 'geojson/ward-4/prop-w4-003.json', 'pending', NULL, NULL, NULL),
('prop-w4-004', '4', 17.687, 83.225, 555, 'new_build', 0.88, '{"ndbi_delta": 0.81, "area_delta": 0.71, "osm_status": 0.61, "ndvi_drop": 0.74, "db_match": 0.64}', '2026-07-12 00:00:00', 'geojson/ward-4/prop-w4-004.json', 'underassessed', '**Analysis for property prop-w4-004**: This property scores 88% confidence for new construction.\n\nNDBI delta (81%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: High priority — schedule field verification within 7 days.', 'system', '2026-07-12 00:00:00'),
('prop-w4-005', '4', 17.695, 83.212, 189, 'change_of_use', 0.67, '{"ndbi_delta": 0.62, "area_delta": 0.55, "osm_status": 0.47, "ndvi_drop": 0.57, "db_match": 0.49}', '2026-07-04 00:00:00', 'geojson/ward-4/prop-w4-005.json', 'false_positive', '**Analysis for property prop-w4-005**: This property scores 67% confidence for change of use.\n\nNDBI delta (62%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-07-04 00:00:00'),
('prop-w4-006', '4', 17.701, 83.218, 632, 'new_build', 0.93, '{"ndbi_delta": 0.88, "area_delta": 0.78, "osm_status": 0.68, "ndvi_drop": 0.81, "db_match": 0.71}', '2026-07-18 00:00:00', 'geojson/ward-4/prop-w4-006.json', 'pending', NULL, NULL, NULL),
('prop-w4-007', '4', 17.688, 83.207, 143, 'change_of_use', 0.58, '{"ndbi_delta": 0.55, "area_delta": 0.49, "osm_status": 0.43, "ndvi_drop": 0.51, "db_match": 0.45}', '2026-07-15 00:00:00', 'geojson/ward-4/prop-w4-007.json', 'pending', NULL, NULL, NULL),
('prop-w4-008', '4', 17.707, 83.222, 478, 'new_build', 0.85, '{"ndbi_delta": 0.82, "area_delta": 0.73, "osm_status": 0.65, "ndvi_drop": 0.76, "db_match": 0.68}', '2026-07-07 00:00:00', 'geojson/ward-4/prop-w4-008.json', 'verified', '**Analysis for property prop-w4-008**: This property scores 85% confidence for new construction.\n\nNDBI delta (82%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: High priority — schedule field verification within 7 days.', 'system', '2026-07-07 00:00:00'),
('prop-w4-009', '4', 17.694, 83.214, 321, 'change_of_use', 0.79, '{"ndbi_delta": 0.77, "area_delta": 0.7, "osm_status": 0.62, "ndvi_drop": 0.72, "db_match": 0.64}', '2026-07-14 00:00:00', 'geojson/ward-4/prop-w4-009.json', 'pending', NULL, NULL, NULL),
('prop-w4-010', '4', 17.69, 83.219, 265, 'new_build', 0.71, '{"ndbi_delta": 0.7, "area_delta": 0.64, "osm_status": 0.58, "ndvi_drop": 0.65, "db_match": 0.6}', '2026-07-01 00:00:00', 'geojson/ward-4/prop-w4-010.json', 'already_assessed', '**Analysis for property prop-w4-010**: This property scores 71% confidence for new construction.\n\nNDBI delta (70%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-07-01 00:00:00'),
('prop-w5-001', '5', 17.682, 83.205, 398, 'new_build', 0.84, '{"ndbi_delta": 0.83, "area_delta": 0.76, "osm_status": 0.69, "ndvi_drop": 0.78, "db_match": 0.71}', '2026-07-17 00:00:00', 'geojson/ward-5/prop-w5-001.json', 'pending', NULL, NULL, NULL),
('prop-w5-002', '5', 17.676, 83.211, 234, 'change_of_use', 0.69, '{"ndbi_delta": 0.62, "area_delta": 0.53, "osm_status": 0.44, "ndvi_drop": 0.56, "db_match": 0.47}', '2026-07-08 00:00:00', 'geojson/ward-5/prop-w5-002.json', 'verified', '**Analysis for property prop-w5-002**: This property scores 69% confidence for change of use.\n\nNDBI delta (62%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: Moderate priority — include in next inspection cycle.', 'system', '2026-07-08 00:00:00'),
('prop-w5-003', '5', 17.689, 83.197, 312, 'new_build', 0.77, '{"ndbi_delta": 0.7, "area_delta": 0.61, "osm_status": 0.52, "ndvi_drop": 0.64, "db_match": 0.54}', '2026-07-19 00:00:00', 'geojson/ward-5/prop-w5-003.json', 'pending', NULL, NULL, NULL),
('prop-w5-004', '5', 17.673, 83.203, 589, 'change_of_use', 0.91, '{"ndbi_delta": 0.84, "area_delta": 0.74, "osm_status": 0.64, "ndvi_drop": 0.77, "db_match": 0.67}', '2026-07-13 00:00:00', 'geojson/ward-5/prop-w5-004.json', 'underassessed', '**Analysis for property prop-w5-004**: This property scores 91% confidence for change of use.\n\nNDBI delta (84%) indicates significant built-up area increase between 2022 and 2024 satellite passes. OSM database shows no registered structure at this location as of last sync.\n\n**Recommendation**: High priority — schedule field verification within 7 days.', 'system', '2026-07-13 00:00:00');

INSERT INTO alerts (id, ward_id, severity, text, created_at) VALUES
('alt-w1-1', '1', 'danger',  '8 high-confidence detections (>85%) in Seethammadhara sector B. Immediate field verification recommended before quarterly assessment deadline.', '2026-07-29 06:00:00'),
('alt-w1-2', '1', 'warning', 'Revenue leakage estimate for ward: ₹12.4L/year based on 3 underassessed commercial conversions on Nowroji Road.', '2026-07-28 14:00:00'),
('alt-w1-3', '1', 'info',    'Pipeline last run completed successfully. 34 change polygons loaded. Next scheduled run: 01 Aug 2026.', '2026-07-27 20:00:00'),
('alt-w2-1', '2', 'warning', '3 properties near RK Beach Road show commercial activity without updated property tax classification.', '2026-07-29 03:00:00'),
('alt-w2-2', '2', 'info',    'Low NDVI detected across 4 parcels — potential paving over green areas for parking. Confidence avg: 70%.', '2026-07-28 08:00:00'),
('alt-w3-1', '3', 'info',    'Routine scan complete. 2 new build detections added to queue. No high-severity anomalies.', '2026-07-27 00:00:00'),
('alt-w4-1', '4', 'danger',  'CRITICAL: 4 multi-story buildings detected in Asilmetta without corresponding building permits. Estimated annual revenue gap: ₹31.8L.', '2026-07-29 07:00:00'),
('alt-w4-2', '4', 'danger',  '2 properties reclassified from residential to commercial use without notification to assessment office.', '2026-07-29 00:00:00'),
('alt-w4-3', '4', 'warning', 'NDBI delta spike (avg 0.31) across Asilmetta Junction — bulk construction suggests multi-unit residential project.', '2026-07-28 10:00:00'),
('alt-w5-1', '5', 'warning', 'prop-w5-004 shows change-of-use with 91% confidence — hospitality / serviced apartment conversion near Dwaraka Nagar circle.', '2026-07-28 18:00:00'),
('alt-w5-2', '5', 'info',    '4 detections verified as false positives (reflective rooftop solar panels). Model refinement queued.', '2026-07-26 12:00:00');

INSERT INTO admin_config (key_name, value) VALUES
('data_mode', 'demo'),
('pipeline_status', 'idle'),
('last_refresh', '2026-07-30T04:00:00.000Z'),
('ndbi_threshold', '0.15'),
('ai_brief', NULL),
('ai_brief_updated_at', NULL);
