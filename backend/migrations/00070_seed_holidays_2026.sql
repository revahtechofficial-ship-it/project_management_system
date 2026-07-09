-- +goose Up
-- Nepal's 2026 holiday calendar. The dates are transcribed from the printed
-- calendar the owner supplied (calendarlabs.com), not computed: the festival
-- days are lunar and have no closed-form formula.
--
-- `is_public` means "office closed nationwide". The source does not record it,
-- so it is derived from the audience the source names in parentheses —
-- (Females), (Sikhs), (Civil Employees), (Kathmandu valley) — plus the ritual
-- days inside Dashain that are not themselves office-closing. Admins can
-- delete and re-add any row whose flag does not match Revah's own policy.
INSERT INTO holidays (holiday_date, name_en, name_ne, is_public) VALUES
    ('2026-01-11', 'Prithvi Jayanti',                     'पृथ्वी जयन्ती',            true),
    ('2026-01-14', 'Maghe Sankranti',                     'माघे संक्रान्ति',           true),
    ('2026-01-30', 'Martyrs'' Day',                       'शहीद दिवस',              true),
    ('2026-02-15', 'Maha Shivaratri',                     'महाशिवरात्री',            true),
    ('2026-02-18', 'Sonam Losar',                         'सोनाम ल्होसार',           true),
    ('2026-02-18', 'Ghyalpo Losar',                       'ग्याल्पो ल्होसार',          true),
    ('2026-02-19', 'Prajatantra Diwas',                   'प्रजातन्त्र दिवस',          true),
    ('2026-03-08', 'International Women''s Day',          'अन्तर्राष्ट्रिय नारी दिवस',   false),
    ('2026-03-18', 'Ghode Jatra (Kathmandu valley)',      'घोडेजात्रा (काठमाडौं उपत्यका)', false),
    ('2026-03-21', 'Ramjan Edul Fikra',                   'रमजान इदुल फित्र',        true),
    ('2026-03-27', 'Ram Navami',                          'रामनवमी',               true),
    ('2026-04-14', 'Nepali New Year',                     'नेपाली नयाँ वर्ष',          true),
    ('2026-04-24', 'Loktantra Diwas',                     'लोकतन्त्र दिवस',          true),
    ('2026-05-01', 'Buddha Jayanti',                      'बुद्ध जयन्ती',             true),
    ('2026-05-01', 'Labour Day',                          'अन्तर्राष्ट्रिय श्रमिक दिवस',  true),
    ('2026-05-27', 'Edul Aajaha',                         'इदुल अजहा',              true),
    ('2026-05-29', 'Ganatantra Diwas',                    'गणतन्त्र दिवस',           true),
    ('2026-08-28', 'Raksha Bandhan',                      'रक्षाबन्धन',              true),
    ('2026-08-29', 'Gai Jatra (Kathmandu valley)',        'गाईजात्रा (काठमाडौं उपत्यका)',  false),
    ('2026-09-04', 'Gaura Parba',                         'गौरा पर्व',               false),
    ('2026-09-04', 'Shree Krishna Janmashtami',           'श्रीकृष्ण जन्माष्टमी',        true),
    ('2026-09-07', 'Nijamati Sewa Diwas (Civil Employees)', 'निजामती सेवा दिवस',     false),
    ('2026-09-14', 'Hartalika Teej (Females)',            'हरितालिका तीज',           false),
    ('2026-09-16', 'Rishi Panchami (Females)',            'ऋषि पञ्चमी',             false),
    ('2026-09-19', 'Constitution Day',                    'संविधान दिवस',            true),
    ('2026-09-25', 'Indra Jatra (Kathmandu valley)',      'इन्द्रजात्रा (काठमाडौं उपत्यका)', false),
    ('2026-10-11', 'Ghatasthapana',                       'घटस्थापना',              true),
    ('2026-10-17', 'Fulpati',                             'फूलपाती',               true),
    ('2026-10-18', 'Maha Ashtami',                        'महाअष्टमी',              true),
    ('2026-10-19', 'Maha Navami',                         'महानवमी',               true),
    ('2026-10-20', 'Vijaya Dashami',                      'विजया दशमी',            true),
    ('2026-10-22', 'Ekadashi',                            'एकादशी',                false),
    ('2026-10-23', 'Dwadashi',                            'द्वादशी',                false),
    ('2026-10-24', 'Kojagrat Purnima',                    'कोजाग्रत पूर्णिमा',         false),
    ('2026-11-08', 'Laxmi Puja',                          'लक्ष्मी पूजा',             true),
    ('2026-11-10', 'Govardhan Puja',                      'गोवर्धन पूजा',            true),
    ('2026-11-11', 'Bhai Tika',                           'भाइटीका',               true),
    ('2026-11-15', 'Chhath Puja',                         'छठ पर्व',                true),
    ('2026-11-24', 'Guru Nanak Jayanti (Sikhs)',          'गुरु नानक जयन्ती',         false),
    ('2026-12-24', 'Udhauli Parva',                       'उधौली पर्व',              false),
    ('2026-12-25', 'Christmas Day',                       'क्रिसमस',                true),
    ('2026-12-30', 'Tamu Losar',                          'तमु ल्होसार',             true)
ON CONFLICT (holiday_date, name_en) DO NOTHING;

-- +goose Down
-- Removes only the seeded rows, by (date, name), so anything an admin added
-- inside 2026 survives a rollback.
DELETE FROM holidays h
USING (
    VALUES
        ('2026-01-11'::date, 'Prithvi Jayanti'),
        ('2026-01-14'::date, 'Maghe Sankranti'),
        ('2026-01-30'::date, 'Martyrs'' Day'),
        ('2026-02-15'::date, 'Maha Shivaratri'),
        ('2026-02-18'::date, 'Sonam Losar'),
        ('2026-02-18'::date, 'Ghyalpo Losar'),
        ('2026-02-19'::date, 'Prajatantra Diwas'),
        ('2026-03-08'::date, 'International Women''s Day'),
        ('2026-03-18'::date, 'Ghode Jatra (Kathmandu valley)'),
        ('2026-03-21'::date, 'Ramjan Edul Fikra'),
        ('2026-03-27'::date, 'Ram Navami'),
        ('2026-04-14'::date, 'Nepali New Year'),
        ('2026-04-24'::date, 'Loktantra Diwas'),
        ('2026-05-01'::date, 'Buddha Jayanti'),
        ('2026-05-01'::date, 'Labour Day'),
        ('2026-05-27'::date, 'Edul Aajaha'),
        ('2026-05-29'::date, 'Ganatantra Diwas'),
        ('2026-08-28'::date, 'Raksha Bandhan'),
        ('2026-08-29'::date, 'Gai Jatra (Kathmandu valley)'),
        ('2026-09-04'::date, 'Gaura Parba'),
        ('2026-09-04'::date, 'Shree Krishna Janmashtami'),
        ('2026-09-07'::date, 'Nijamati Sewa Diwas (Civil Employees)'),
        ('2026-09-14'::date, 'Hartalika Teej (Females)'),
        ('2026-09-16'::date, 'Rishi Panchami (Females)'),
        ('2026-09-19'::date, 'Constitution Day'),
        ('2026-09-25'::date, 'Indra Jatra (Kathmandu valley)'),
        ('2026-10-11'::date, 'Ghatasthapana'),
        ('2026-10-17'::date, 'Fulpati'),
        ('2026-10-18'::date, 'Maha Ashtami'),
        ('2026-10-19'::date, 'Maha Navami'),
        ('2026-10-20'::date, 'Vijaya Dashami'),
        ('2026-10-22'::date, 'Ekadashi'),
        ('2026-10-23'::date, 'Dwadashi'),
        ('2026-10-24'::date, 'Kojagrat Purnima'),
        ('2026-11-08'::date, 'Laxmi Puja'),
        ('2026-11-10'::date, 'Govardhan Puja'),
        ('2026-11-11'::date, 'Bhai Tika'),
        ('2026-11-15'::date, 'Chhath Puja'),
        ('2026-11-24'::date, 'Guru Nanak Jayanti (Sikhs)'),
        ('2026-12-24'::date, 'Udhauli Parva'),
        ('2026-12-25'::date, 'Christmas Day'),
        ('2026-12-30'::date, 'Tamu Losar')
) AS seeded (d, n)
WHERE h.holiday_date = seeded.d AND h.name_en = seeded.n;
