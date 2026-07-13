-- +goose Up
-- The parts of a patro that cannot be computed, only written or looked up.
--
-- Three tables, and each exists because the thing it holds is *not* derivable.
-- The tithi is arithmetic and lives in the client. A quote is somebody's words.
-- An international day is a resolution somebody passed. A rashifal is written
-- by an astrologer. None of them can be worked out from the position of the
-- moon, so none of them is guessed at here.

-- International days, national days, awareness days: fixed to a Gregorian
-- month and day, and therefore recurring for ever without re-seeding. Storing
-- a year would mean adding 2027's list, then 2028's, for a day that never
-- moves.
CREATE TABLE observances (
    id         BIGSERIAL PRIMARY KEY,
    month      INT       NOT NULL,
    day        INT       NOT NULL,
    name_en    TEXT      NOT NULL,
    name_ne    TEXT      NOT NULL DEFAULT '',
    scope      TEXT      NOT NULL DEFAULT 'international',
    note_en    TEXT      NOT NULL DEFAULT '',
    note_ne    TEXT      NOT NULL DEFAULT '',
    source     TEXT      NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT observances_month_check CHECK (month BETWEEN 1 AND 12),
    CONSTRAINT observances_day_check CHECK (day BETWEEN 1 AND 31),
    CONSTRAINT observances_scope_check CHECK (scope IN
        ('international', 'national', 'awareness')),
    CONSTRAINT observances_name_check CHECK (name_en <> '')
);

CREATE INDEX idx_observances_day ON observances (month, day);
CREATE UNIQUE INDEX idx_observances_unique ON observances (month, day, name_en);

-- Quote of the day. Rotated deterministically by the day of the year, so the
-- same day always shows the same quote and nobody has to schedule anything.
CREATE TABLE quotes (
    id         BIGSERIAL PRIMARY KEY,
    text_en    TEXT      NOT NULL DEFAULT '',
    text_ne    TEXT      NOT NULL DEFAULT '',
    author     TEXT      NOT NULL DEFAULT '',
    source     TEXT      NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- A quote with no text is not a quote.
    CONSTRAINT quotes_text_check CHECK (text_en <> '' OR text_ne <> '')
);

-- Rashifal: the horoscope reading for one sign over one period.
--
-- There is no algorithm for this and there never was. A rashifal is composed
-- by an astrologer, and Hamro Patro's is written, not generated. So this table
-- is empty until somebody fills it, and the card says as much rather than
-- inventing a prediction — which would be the one thing on this page that is
-- simply made up.
--
-- `source` is not decoration. A reading with no attribution is nobody's but
-- the person who typed it, and the reader is entitled to know that.
CREATE TABLE rashifal (
    id         BIGSERIAL PRIMARY KEY,

    -- 0 = Mesh (Aries) .. 11 = Meen (Pisces).
    rashi      INT       NOT NULL,
    period     TEXT      NOT NULL,

    -- The span it covers. A daily reading has from_date = to_date.
    from_date  DATE      NOT NULL,
    to_date    DATE      NOT NULL,

    text_en    TEXT      NOT NULL DEFAULT '',
    text_ne    TEXT      NOT NULL DEFAULT '',
    source     TEXT      NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT rashifal_rashi_check CHECK (rashi BETWEEN 0 AND 11),
    CONSTRAINT rashifal_period_check CHECK (period IN
        ('daily', 'weekly', 'monthly')),
    CONSTRAINT rashifal_span_check CHECK (to_date >= from_date),
    CONSTRAINT rashifal_text_check CHECK (text_en <> '' OR text_ne <> '')
);

CREATE INDEX idx_rashifal_lookup ON rashifal (rashi, period, from_date);
CREATE UNIQUE INDEX idx_rashifal_unique
    ON rashifal (rashi, period, from_date);

-- +goose Down
DROP TABLE rashifal;
DROP TABLE quotes;
DROP TABLE observances;
