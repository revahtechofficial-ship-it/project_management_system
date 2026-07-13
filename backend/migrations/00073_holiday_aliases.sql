-- +goose Up
-- Alternate names for a festival, comma-separated: the umbrella it belongs to
-- ("Dashain"), the name another community uses ("Janai Purnima"), and the
-- Nepali spelling. Searching or scanning for "Dashain" found nothing before
-- this, because the table only ever held the day's formal name.
ALTER TABLE holidays ADD COLUMN aliases TEXT NOT NULL DEFAULT '';

UPDATE holidays SET aliases = 'Dashain, बडा दशैं, दशैं, Bijaya Dashami, Bada Dashain'
    WHERE name_en = 'Vijaya Dashami';
UPDATE holidays SET aliases = 'Dashain, दशैं, Navaratra Arambha'
    WHERE name_en = 'Ghatasthapana';
UPDATE holidays SET aliases = 'Dashain, दशैं' WHERE name_en IN
    ('Fulpati', 'Maha Ashtami', 'Maha Navami', 'Ekadashi', 'Dwadashi');
UPDATE holidays SET aliases = 'Tihar, तिहार, Deepawali, Diwali, Kukur Tihar'
    WHERE name_en = 'Laxmi Puja';
UPDATE holidays SET aliases = 'Tihar, तिहार, Mha Puja, Goru Puja, Hali Tihar'
    WHERE name_en = 'Govardhan Puja';
UPDATE holidays SET aliases = 'Tihar, तिहार, Kija Puja, Bhai Dooj'
    WHERE name_en = 'Bhai Tika';
UPDATE holidays SET aliases =
    'Janai Purnima, जनै पूर्णिमा, Kwati Khane Din, Rishi Tarpani'
    WHERE name_en = 'Raksha Bandhan';
UPDATE holidays SET aliases = 'Chhath, छठ, Surya Puja'
    WHERE name_en = 'Chhath Puja';
UPDATE holidays SET aliases = 'Makar Sankranti, Maghi, माघी, Uttarayan'
    WHERE name_en = 'Maghe Sankranti';
UPDATE holidays SET aliases = 'Chandi Purnima, Ubhauli Parva, Vesak'
    WHERE name_en = 'Buddha Jayanti';
UPDATE holidays SET aliases = 'Teej, तीज, Haritalika Teej'
    WHERE name_en = 'Hartalika Teej (Females)';
UPDATE holidays SET aliases = 'Rashtriya Ekata Diwas'
    WHERE name_en = 'Prithvi Jayanti';

-- +goose Down
ALTER TABLE holidays DROP COLUMN aliases;
