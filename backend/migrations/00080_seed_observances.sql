-- +goose Up
-- International and national days.
--
-- Every row marked "BS 2083 list" was printed on the calendar the owner
-- supplied, so it is attested rather than recalled. The rest are UN-designated
-- days whose dates are fixed by resolution and have not moved; they are marked
-- as such, and any that Revah does not care about can simply be deleted.
--
-- Nothing here is a guess. A day whose date I was not sure of is not in the
-- list — an observance on the wrong day is worse than one that is missing.
INSERT INTO observances (month, day, name_en, name_ne, scope, source) VALUES
    -- From the BS 2083 festival list the owner supplied.
    (3, 21, 'World Poetry Day', 'विश्व कविता दिवस', 'international',
     'BS 2083 list'),
    (3, 22, 'World Water Day', 'विश्व पानी दिवस', 'international',
     'BS 2083 list'),
    (5, 29, 'International Everest Day', 'सगरमाथा दिवस', 'national',
     'BS 2083 list'),
    (6, 20, 'World Refugee Day', 'विश्व शरणार्थी दिवस', 'international',
     'BS 2083 list'),
    (7, 11, 'World Population Day', 'विश्व जनसंख्या दिवस', 'international',
     'BS 2083 list'),
    (8, 28, 'Sanskrit Day', 'संस्कृत दिवस', 'national', 'BS 2083 list'),
    (8, 29, 'International Day Against Nuclear Tests',
     'अन्तर्राष्ट्रिय आणविक परीक्षण विरुद्ध दिवस', 'international',
     'BS 2083 list'),
    (9, 14, 'National Children''s Day', 'राष्ट्रिय बाल दिवस', 'national',
     'BS 2083 list'),
    (9, 25, 'World Pharmacists Day', 'विश्व औषधि विज्ञ दिवस',
     'international', 'BS 2083 list'),
    (10, 4, 'World Animal Day', 'विश्व पशु दिवस', 'international',
     'BS 2083 list'),
    (10, 17, 'International Day for the Eradication of Poverty',
     'अन्तर्राष्ट्रिय गरिबी निवारण दिवस', 'international', 'BS 2083 list'),
    (11, 8, 'World Radiography Day', 'विश्व रेडियोग्राफी दिवस',
     'international', 'BS 2083 list'),
    (11, 9, 'World Freedom Day', 'विश्व स्वतन्त्रता दिवस', 'international',
     'BS 2083 list'),
    (11, 10, 'World Science Day for Peace and Development',
     'विश्व विज्ञान दिवस', 'international', 'BS 2083 list'),
    (11, 12, 'World Pneumonia Day', 'विश्व निमोनिया दिवस', 'international',
     'BS 2083 list'),
    (12, 3, 'International Day of Persons with Disabilities',
     'अन्तर्राष्ट्रिय अपाङ्गता दिवस', 'international', 'BS 2083 list'),

    -- From the Ministry of Home Affairs gazette for BS 2082.
    (5, 1, 'International Labour Day', 'अन्तर्राष्ट्रिय श्रमिक दिवस',
     'international', 'MoHA gazette BS 2082'),
    (3, 8, 'International Women''s Day', 'अन्तर्राष्ट्रिय नारी दिवस',
     'international', 'MoHA gazette BS 2082'),

    -- UN-designated days, fixed by resolution.
    (4, 7, 'World Health Day', 'विश्व स्वास्थ्य दिवस', 'international', 'UN'),
    (4, 22, 'International Mother Earth Day', 'विश्व पृथ्वी दिवस',
     'international', 'UN'),
    (5, 3, 'World Press Freedom Day', 'विश्व प्रेस स्वतन्त्रता दिवस',
     'international', 'UN'),
    (6, 5, 'World Environment Day', 'विश्व वातावरण दिवस', 'international',
     'UN'),
    (6, 14, 'World Blood Donor Day', 'विश्व रक्तदाता दिवस', 'international',
     'UN'),
    (6, 21, 'International Day of Yoga', 'अन्तर्राष्ट्रिय योग दिवस',
     'international', 'UN'),
    (9, 8, 'International Literacy Day', 'अन्तर्राष्ट्रिय साक्षरता दिवस',
     'international', 'UN'),
    (9, 21, 'International Day of Peace', 'अन्तर्राष्ट्रिय शान्ति दिवस',
     'international', 'UN'),
    (9, 27, 'World Tourism Day', 'विश्व पर्यटन दिवस', 'international', 'UN'),
    (10, 5, 'World Teachers'' Day', 'विश्व शिक्षक दिवस', 'international',
     'UN'),
    (10, 10, 'World Mental Health Day', 'विश्व मानसिक स्वास्थ्य दिवस',
     'international', 'WHO'),
    (11, 20, 'World Children''s Day', 'विश्व बाल दिवस', 'international', 'UN'),
    (12, 1, 'World AIDS Day', 'विश्व एड्स दिवस', 'international', 'UN'),
    (12, 10, 'Human Rights Day', 'मानव अधिकार दिवस', 'international', 'UN')
ON CONFLICT (month, day, name_en) DO NOTHING;

-- +goose Down
DELETE FROM observances WHERE source IN
    ('BS 2083 list', 'MoHA gazette BS 2082', 'UN', 'WHO');
