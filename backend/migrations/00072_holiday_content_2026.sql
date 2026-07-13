-- +goose Up
-- Classifies every seeded 2026 holiday, and writes festival prose for the
-- widely-documented ones.
--
-- The categories are derived from the source's own parenthetical audiences
-- (Kathmandu valley -> local, Females/Sikhs/Civil Employees -> the community
-- that observes it) and from what the day commemorates. The prose is a plain
-- summary of what is broadly agreed about each festival; it is deliberately
-- short, avoids contested dates and attributions, and is editable by any admin
-- from the calendar. Days not named below keep category 'other' and no prose.

UPDATE holidays SET category = 'national' WHERE name_en IN (
    'Prithvi Jayanti', 'Martyrs'' Day', 'Prajatantra Diwas',
    'Loktantra Diwas', 'Ganatantra Diwas', 'Constitution Day',
    'Nepali New Year', 'Nijamati Sewa Diwas (Civil Employees)');

UPDATE holidays SET category = 'international' WHERE name_en IN (
    'International Women''s Day', 'Labour Day');

UPDATE holidays SET category = 'local' WHERE name_en IN (
    'Ghode Jatra (Kathmandu valley)', 'Gai Jatra (Kathmandu valley)',
    'Indra Jatra (Kathmandu valley)', 'Gaura Parba', 'Udhauli Parva');

UPDATE holidays SET category = 'religious' WHERE name_en IN (
    'Maghe Sankranti', 'Maha Shivaratri', 'Sonam Losar', 'Ghyalpo Losar',
    'Ramjan Edul Fikra', 'Ram Navami', 'Buddha Jayanti', 'Edul Aajaha',
    'Raksha Bandhan', 'Shree Krishna Janmashtami', 'Hartalika Teej (Females)',
    'Rishi Panchami (Females)', 'Ghatasthapana', 'Fulpati', 'Maha Ashtami',
    'Maha Navami', 'Vijaya Dashami', 'Ekadashi', 'Dwadashi',
    'Kojagrat Purnima', 'Laxmi Puja', 'Govardhan Puja', 'Bhai Tika',
    'Chhath Puja', 'Guru Nanak Jayanti (Sikhs)', 'Christmas Day',
    'Tamu Losar');

UPDATE holidays SET
    description_en = 'Marks the sun''s turn to the north and the first day of Magh, the coldest month behind and longer days ahead.',
    description_ne = 'सूर्य उत्तरायण हुने दिन र माघ महिनाको पहिलो दिन।',
    history_en = 'A solar observance kept on the first of Magh in the Bikram Sambat calendar, marked across South Asia under different names.',
    importance_en = 'Regarded as an auspicious turning point after the winter solstice; a public holiday in Nepal.',
    celebration_en = 'Families eat til ko laddu, chaku, ghee, sweet potato and yam. Many bathe at river confluences such as Devghat and Sankhu.'
WHERE name_en = 'Maghe Sankranti';

UPDATE holidays SET
    description_en = 'Marks the birth, enlightenment and passing of Siddhartha Gautama, the Buddha — all three traditionally observed on the full moon of Baisakh.',
    description_ne = 'गौतम बुद्धको जन्म, ज्ञान प्राप्ति र महापरिनिर्वाणको दिन।',
    history_en = 'Siddhartha Gautama was born at Lumbini, in present-day Nepal. The day is also called Baisakh Purnima, and Vesak elsewhere in Asia.',
    importance_en = 'The most significant day in the Buddhist calendar, and a public holiday in Nepal.',
    celebration_en = 'Pilgrims gather at Lumbini, Swayambhunath and Boudhanath. Monasteries hold prayers and butter lamps are lit.'
WHERE name_en = 'Buddha Jayanti';

UPDATE holidays SET
    description_en = 'Janai Purnima, also observed as Raksha Bandhan. The sacred thread is changed, and a protective doro is tied on the wrist.',
    description_ne = 'जनै पूर्णिमा, रक्षाबन्धन पनि भनिन्छ। जनै फेरिन्छ र हातमा डोरो बाँधिन्छ।',
    history_en = 'Falls on the full moon of Shrawan. Brahmin and Chhetri men change the janai; the wrist thread is tied by anyone.',
    importance_en = 'One of the year''s principal full-moon observances, and a public holiday.',
    celebration_en = 'Kwati, a soup of nine sprouted beans, is eaten. Pilgrims travel to Gosaikunda and to Kumbheshwar in Patan.'
WHERE name_en = 'Raksha Bandhan';

UPDATE holidays SET
    description_en = 'Women fast for the wellbeing of a husband, or for a good match, traditionally without food or water.',
    description_ne = 'महिलाहरूले पतिको दीर्घायुको कामना गर्दै निराहार व्रत बस्ने पर्व।',
    history_en = 'Named for the legend of Parvati''s austerities to win Shiva as her husband.',
    importance_en = 'Widely observed by Hindu women across Nepal. A holiday for women rather than a nationwide one.',
    celebration_en = 'Red saris, dar khane the night before, songs and dancing, and worship at Pashupatinath.'
WHERE name_en = 'Hartalika Teej (Females)';

UPDATE holidays SET
    description_en = 'A four-day festival to the sun god Surya and to Chhathi Maiya, most widely kept in the Tarai and Madhesh.',
    description_ne = 'सूर्य र छठी माईको पूजा गरिने चार दिने पर्व।',
    history_en = 'A sun observance of the Tarai, now kept across Nepal wherever its communities have settled.',
    importance_en = 'Among the most demanding of Nepali fasts, and a public holiday.',
    celebration_en = 'Offerings are made standing in a river or pond, first to the setting sun and again to the rising sun the next morning.'
WHERE name_en = 'Chhath Puja';

UPDATE holidays SET
    description_en = 'The first day of Dashain, Nepal''s longest festival. A kalash is set in a bed of sand and barley is sown; the jamara sprouts by Dashami.',
    description_ne = 'दशैंको पहिलो दिन। कलश स्थापना गरी जमरा राखिन्छ।',
    history_en = 'Opens the fifteen days of Dashain, which run to Kojagrat Purnima.',
    importance_en = 'Begins the year''s longest public holiday.',
    celebration_en = 'The kalash is set at an auspicious hour and tended for nine days.'
WHERE name_en = 'Ghatasthapana';

UPDATE holidays SET
    description_en = 'The tenth and principal day of Dashain, Nepal''s longest and most widely observed festival.',
    description_ne = 'दशैंको मुख्य दिन — टीका र जमरा ग्रहण गरिने दिन।',
    history_en = 'Celebrates the goddess Durga''s victory over the demon Mahishasura. Dashain runs fifteen days, from Ghatasthapana to Kojagrat Purnima.',
    importance_en = 'The great day of family reunion, and the longest public holiday of the Nepali year.',
    celebration_en = 'Elders place tika of rice, yoghurt and vermilion on the foreheads of younger relatives, give jamara and dakshina, and bless them.'
WHERE name_en = 'Vijaya Dashami';

UPDATE holidays SET
    description_en = 'The third day of Tihar, the festival of lights. Homes are cleaned and lit to welcome Lakshmi, goddess of wealth.',
    description_ne = 'तिहारको तेस्रो दिन — लक्ष्मी पूजा। घर सफा गरी दियो बालिन्छ।',
    history_en = 'Tihar honours a different being on each of its five days: crow, dog, cow, ox, and finally brothers.',
    importance_en = 'The central day of Tihar, and a public holiday.',
    celebration_en = 'Oil lamps and rangoli mark the doorway, and groups sing deusi and bhailo from house to house.'
WHERE name_en = 'Laxmi Puja';

UPDATE holidays SET
    description_en = 'The final day of Tihar. Sisters place a seven-coloured tika on their brothers'' foreheads and wish them long life.',
    description_ne = 'तिहारको अन्तिम दिन — दिदीबहिनीले दाजुभाइलाई सप्तरंगी टीका लगाइदिन्छन्।',
    history_en = 'The fifth and last day of Tihar, following Govardhan Puja.',
    importance_en = 'A public holiday, and the close of the Tihar week.',
    celebration_en = 'Sisters encircle their brothers with oil, garland them with makhamali flowers, and receive gifts in return.'
WHERE name_en = 'Bhai Tika';

-- +goose Down
UPDATE holidays SET
    category = 'other',
    description_en = '', description_ne = '',
    history_en = '', history_ne = '',
    importance_en = '', importance_ne = '',
    celebration_en = '', celebration_ne = ''
WHERE holiday_date >= '2026-01-01' AND holiday_date <= '2026-12-31';
