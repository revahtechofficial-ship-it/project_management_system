-- +goose Up
-- A single is_public boolean cannot say what the Ministry of Home Affairs
-- gazette actually says. The gazette closes different things for different
-- days: Saraswati Puja shuts schools but not offices; Teej is a holiday for
-- women employees only; Gai Jatra is a holiday in the Kathmandu valley;
-- Guru Nanak Jayanti is a holiday for the community that keeps it. Those are
-- independent facts, so they are independent columns.
--
-- is_public is kept and left meaning what it always meant — "the office is
-- closed nationwide" — so nothing that reads it changes behaviour.
ALTER TABLE holidays
    ADD COLUMN is_government BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN is_bank       BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN is_school     BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN is_optional   BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN observed_by   TEXT    NOT NULL DEFAULT '';

COMMENT ON COLUMN holidays.is_public IS
    'Office closed nationwide (the gazette''s "sarbajanik bida").';
COMMENT ON COLUMN holidays.is_optional IS
    'Kept only by the community, region or group named in observed_by.';
COMMENT ON COLUMN holidays.observed_by IS
    'Who keeps it: Kirat, Newar, Tamang, Sherpa, Gurung, Tharu, Mithila, '
    'Muslim, Sikh, Christian, Women, Students, Kathmandu Valley, ... '
    'Blank means everyone.';

-- A nationwide public holiday closes government offices, banks and schools
-- alike. Start from that, then correct the exceptions below.
UPDATE holidays
SET is_government = true, is_bank = true, is_school = true
WHERE is_public;

-- Days the gazette gives to one group rather than to the country.
UPDATE holidays SET is_public = false, is_government = false, is_bank = false,
                    is_school = false, is_optional = true,
                    observed_by = 'Students, Teachers'
WHERE name_en LIKE 'Basanta Panchami%';

UPDATE holidays SET is_optional = true, observed_by = 'Women'
WHERE name_en LIKE 'Hartalika Teej%';

UPDATE holidays SET is_optional = true, observed_by = 'Women'
WHERE name_en IN ('Rishi Panchami (Females)', 'Jitiya Parva');

UPDATE holidays SET is_optional = true, observed_by = 'Sikh'
WHERE name_en LIKE 'Guru Nanak Jayanti%';

UPDATE holidays SET is_optional = true, observed_by = 'Christian'
WHERE name_en = 'Christmas Day';

UPDATE holidays SET is_optional = true, observed_by = 'Muslim'
WHERE name_en IN ('Ramjan Edul Fikra', 'Edul Aajaha');

UPDATE holidays SET is_optional = true, observed_by = 'Tamang'
WHERE name_en = 'Sonam Losar';
UPDATE holidays SET is_optional = true, observed_by = 'Sherpa, Tibetan'
WHERE name_en = 'Ghyalpo Losar';
UPDATE holidays SET is_optional = true, observed_by = 'Gurung'
WHERE name_en = 'Tamu Losar';
UPDATE holidays SET is_optional = true, observed_by = 'Kirat'
WHERE name_en = 'Udhauli Parva';

UPDATE holidays SET is_optional = true, observed_by = 'Kathmandu Valley'
WHERE name_en LIKE '%(Kathmandu valley)%' OR name_en = 'Bhoto Jatra';

UPDATE holidays SET is_optional = true, observed_by = 'Sudurpashchim'
WHERE name_en = 'Gaura Parba';

UPDATE holidays SET is_optional = true, observed_by = 'Civil servants'
WHERE name_en LIKE 'Nijamati Sewa Diwas%';

UPDATE holidays SET observed_by = 'Terai districts'
WHERE name_en LIKE '%Holi (Tarai%';
UPDATE holidays SET observed_by = 'Hill and mountain districts'
WHERE name_en LIKE '%Holi (hill%';

-- +goose Down
ALTER TABLE holidays
    DROP COLUMN is_government,
    DROP COLUMN is_bank,
    DROP COLUMN is_school,
    DROP COLUMN is_optional,
    DROP COLUMN observed_by;
