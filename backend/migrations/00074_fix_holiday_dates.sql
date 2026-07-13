-- +goose Up
-- Corrects the 2026 holidays against two authoritative sources the owner
-- supplied, replacing the calendarlabs.com dates seeded in 00072:
--
--   * The Government of Nepal, Ministry of Home Affairs gazette for BS 2082
--     (Nepal Rajpatra, Khanda 74, Sankhya 59) — the official public-holiday
--     list, covering Apr 2025 to Apr 2026.
--   * A published BS 2083 festival list giving both BS and AD dates for each
--     day, covering Apr 2026 to Apr 2027.
--
-- Both were checked against our own converter before being trusted:
-- test/bs_2083_source_test.dart asserts all 44 of the BS 2083 list's
-- (BS, AD) pairs, and every weekday the gazette names for BS 2082 —
-- "Magh 1, Thursday", "Falgun 18, Monday" — lands on that weekday here. The
-- conversion arithmetic is not in question; the calendarlabs *festival* dates
-- were simply wrong.
--
-- Five corrections, and each is a day a Nepali office actually closes:

-- Magh 1 is Maghe Sankranti by definition. The gazette puts Magh 1 on a
-- Thursday, which is 15 January 2026, not the 14th.
UPDATE holidays SET holiday_date = '2026-01-15'
    WHERE name_en = 'Maghe Sankranti' AND holiday_date = '2026-01-14';

-- Sonam Losar (Tamang new year, gazette: Magh 5, Monday = 19 Jan) had been
-- seeded onto 18 February — the same day as Ghyalpo Losar (Sherpa/Tibetan new
-- year, gazette: Falgun 6, Wednesday). They are a month apart and cannot share
-- a date; the seed collapsed the two Losars onto one day.
UPDATE holidays SET holiday_date = '2026-01-19'
    WHERE name_en = 'Sonam Losar' AND holiday_date = '2026-02-18';

-- The Dashain week was a day early throughout. The BS 2083 list runs
-- Kartik 1 = Maha Ashtami (18 Oct), Kartik 3 = Maha Navami (20 Oct),
-- Kartik 4 = Vijaya Dashami (21 Oct), Kartik 5 = Ekadashi (22 Oct),
-- Kartik 6 = Dwadashi (23 Oct). The seeded data agreed on Ashtami, Ekadashi
-- and Dwadashi but placed Navami and Dashami a day earlier — which left 21
-- October unaccounted for between Dashami and Ekadashi. It is not a leap that
-- tithi can make.
UPDATE holidays SET holiday_date = '2026-10-20'
    WHERE name_en = 'Maha Navami' AND holiday_date = '2026-10-19';
UPDATE holidays SET holiday_date = '2026-10-21'
    WHERE name_en = 'Vijaya Dashami' AND holiday_date = '2026-10-20';

-- Bakar Eid / Eid al-Adha: Jestha 14 in the BS 2083 list is 28 May.
UPDATE holidays SET holiday_date = '2026-05-28'
    WHERE name_en = 'Edul Aajaha' AND holiday_date = '2026-05-27';

-- Kojagrat Purnima was seeded on 24 October. With Dwadashi now confirmed on
-- the 23rd by both sources, Purnima — three tithi later — cannot fall on the
-- 24th. Neither source names it, so rather than guess a replacement the row is
-- removed; add it back once a trusted date is to hand.
DELETE FROM holidays
    WHERE name_en = 'Kojagrat Purnima' AND holiday_date = '2026-10-24';

-- Festivals the calendarlabs list omitted entirely, from the gazette and the
-- BS 2083 list. Holi is the notable one: the gazette splits it, Falgun 18
-- (Monday) across 56 hill and mountain districts and Falgun 19 (Tuesday) in
-- the named Tarai districts, so it is two rows, not one.
INSERT INTO holidays (holiday_date, name_en, name_ne, is_public, category,
                      aliases, description_en, description_ne) VALUES
    ('2026-03-02', 'Fagu Purnima / Holi (hill districts)',
     'फागु पूर्णिमा / होली (पहाडी जिल्ला)', true, 'religious',
     'Holi, होली, Fagu, Festival of Colours',
     'The festival of colours, marking the full moon of Falgun. A public holiday across 56 hill and mountain districts on this day, and in the Tarai the day after.',
     'रंगहरूको पर्व। फागुन पूर्णिमाको दिन मनाइन्छ।'),
    ('2026-03-03', 'Fagu Purnima / Holi (Tarai districts)',
     'फागु पूर्णिमा / होली (तराई जिल्ला)', true, 'religious',
     'Holi, होली, Fagu, Festival of Colours',
     'Holi in the Tarai, kept a day after the hill districts — the Ministry of Home Affairs names twenty-one districts, from Jhapa to Kanchanpur.',
     'तराईका जिल्लामा होली, पहाडभन्दा एक दिनपछि।'),
    ('2026-01-23', 'Basanta Panchami / Saraswati Puja',
     'बसन्त पञ्चमी / सरस्वती पूजा', false, 'religious',
     'Saraswati Puja, सरस्वती पूजा, Shree Panchami',
     'Worship of Saraswati, goddess of learning; the gazette makes it a holiday for educational institutions rather than a nationwide one.',
     'विद्याकी देवी सरस्वतीको पूजा। शिक्षण संस्थाका लागि मात्र बिदा।'),
    ('2026-10-04', 'Jitiya Parva', 'जितिया पर्व', false, 'religious',
     'Jivitputrika, Jitiya',
     'A fast kept by mothers for the long life of their children, observed chiefly in the Tarai and Madhesh.',
     'आमाहरूले सन्तानको दीर्घायुका लागि बस्ने व्रत।'),
    ('2026-06-20', 'Bhoto Jatra', 'भोटो जात्रा', false, 'local',
     'Rato Machhindranath, Sithi Nakha',
     'The showing of the sacred vest that closes the Rato Machhindranath chariot festival in Patan. The gazette leaves the date open — it falls on whichever day the jatra reaches it.',
     'पाटनको रातो मच्छिन्द्रनाथ जात्राको अन्त्यमा भोटो देखाइने दिन।')
ON CONFLICT (holiday_date, name_en) DO NOTHING;

-- +goose Down
UPDATE holidays SET holiday_date = '2026-01-14'
    WHERE name_en = 'Maghe Sankranti' AND holiday_date = '2026-01-15';
UPDATE holidays SET holiday_date = '2026-02-18'
    WHERE name_en = 'Sonam Losar' AND holiday_date = '2026-01-19';
UPDATE holidays SET holiday_date = '2026-10-19'
    WHERE name_en = 'Maha Navami' AND holiday_date = '2026-10-20';
UPDATE holidays SET holiday_date = '2026-10-20'
    WHERE name_en = 'Vijaya Dashami' AND holiday_date = '2026-10-21';
UPDATE holidays SET holiday_date = '2026-05-27'
    WHERE name_en = 'Edul Aajaha' AND holiday_date = '2026-05-28';
INSERT INTO holidays (holiday_date, name_en, name_ne, is_public)
    VALUES ('2026-10-24', 'Kojagrat Purnima', 'कोजाग्रत पूर्णिमा', false)
    ON CONFLICT (holiday_date, name_en) DO NOTHING;
DELETE FROM holidays WHERE name_en IN (
    'Fagu Purnima / Holi (hill districts)',
    'Fagu Purnima / Holi (Tarai districts)',
    'Basanta Panchami / Saraswati Puja',
    'Jitiya Parva',
    'Bhoto Jatra');
