-- +goose Up
-- The calendar looks two years forward by default, so it needs the first part
-- of 2027. These are the BS 2083 list's own entries for Poush 2083 onward —
-- the AD dates are the ones it publishes, and every one is asserted in
-- test/bs_2083_source_test.dart against our converter.
--
-- BS 2083 runs to Chaitra (mid-April 2027), so this stops there. The rest of
-- 2027 belongs to BS 2084 and needs a source for that year.
INSERT INTO holidays (holiday_date, name_en, name_ne, is_public, category,
                      aliases) VALUES
    ('2027-01-11', 'Prithvi Jayanti', 'पृथ्वी जयन्ती', true, 'national',
     'Rashtriya Ekata Diwas'),
    ('2027-01-15', 'Maghe Sankranti', 'माघे संक्रान्ति', true, 'religious',
     'Makar Sankranti, Maghi, माघी, Uttarayan'),
    ('2027-01-30', 'Martyrs'' Day', 'शहीद दिवस', true, 'national', ''),
    ('2027-02-07', 'Sonam Losar', 'सोनाम ल्होसार', true, 'religious',
     'Tamang New Year'),
    ('2027-02-11', 'Basanta Panchami / Saraswati Puja',
     'बसन्त पञ्चमी / सरस्वती पूजा', false, 'religious',
     'Saraswati Puja, सरस्वती पूजा, Shree Panchami'),
    ('2027-02-19', 'Prajatantra Diwas', 'प्रजातन्त्र दिवस', true, 'national',
     ''),
    ('2027-03-06', 'Maha Shivaratri', 'महाशिवरात्री', true, 'religious',
     'Nepali Army Day'),
    ('2027-03-08', 'International Women''s Day',
     'अन्तर्राष्ट्रिय नारी दिवस', false, 'international', ''),
    ('2027-03-09', 'Gyalpo Losar', 'ग्याल्पो ल्होसार', true, 'religious',
     'Sherpa New Year, Tibetan New Year'),
    ('2027-03-21', 'Fagu Purnima / Holi (hill districts)',
     'फागु पूर्णिमा / होली (पहाडी जिल्ला)', true, 'religious',
     'Holi, होली, Fagu, Festival of Colours'),
    ('2027-03-22', 'Fagu Purnima / Holi (Tarai districts)',
     'फागु पूर्णिमा / होली (तराई जिल्ला)', true, 'religious',
     'Holi, होली, Fagu, Festival of Colours'),
    ('2027-04-06', 'Ghode Jatra (Kathmandu valley)',
     'घोडेजात्रा (काठमाडौं उपत्यका)', false, 'local', '')
ON CONFLICT (holiday_date, name_en) DO NOTHING;

-- +goose Down
DELETE FROM holidays
    WHERE holiday_date >= '2027-01-01' AND holiday_date <= '2027-04-30';
