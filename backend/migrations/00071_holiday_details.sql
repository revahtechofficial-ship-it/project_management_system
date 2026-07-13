-- +goose Up
-- A holiday grows from a name and a date into a festival entry: what kind of
-- festival it is, and prose an admin can author for each of the four things a
-- reader wants to know. Every prose column has an English and a Nepali side;
-- the client falls back to the other language when one is blank.
ALTER TABLE holidays
    ADD COLUMN category       TEXT NOT NULL DEFAULT 'other',
    ADD COLUMN description_en TEXT NOT NULL DEFAULT '',
    ADD COLUMN description_ne TEXT NOT NULL DEFAULT '',
    ADD COLUMN history_en     TEXT NOT NULL DEFAULT '',
    ADD COLUMN history_ne     TEXT NOT NULL DEFAULT '',
    ADD COLUMN importance_en  TEXT NOT NULL DEFAULT '',
    ADD COLUMN importance_ne  TEXT NOT NULL DEFAULT '',
    ADD COLUMN celebration_en TEXT NOT NULL DEFAULT '',
    ADD COLUMN celebration_ne TEXT NOT NULL DEFAULT '';

-- `is_public` already answers "is the office closed"; `category` answers "what
-- kind of day is this", and the two are independent — Christmas is religious
-- and public, Gai Jatra is local and not.
ALTER TABLE holidays
    ADD CONSTRAINT holidays_category_check
    CHECK (category IN
        ('religious', 'national', 'local', 'international', 'other'));

CREATE INDEX idx_holidays_category ON holidays (category);

-- +goose Down
DROP INDEX IF EXISTS idx_holidays_category;
ALTER TABLE holidays DROP CONSTRAINT IF EXISTS holidays_category_check;
ALTER TABLE holidays
    DROP COLUMN category,
    DROP COLUMN description_en,
    DROP COLUMN description_ne,
    DROP COLUMN history_en,
    DROP COLUMN history_ne,
    DROP COLUMN importance_en,
    DROP COLUMN importance_ne,
    DROP COLUMN celebration_en,
    DROP COLUMN celebration_ne;
