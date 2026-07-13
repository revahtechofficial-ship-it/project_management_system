-- +goose Up
-- Saait: the auspicious days for a marriage, a bratabandha, a griha pravesh.
--
-- Unlike Rahu Kaal — which is arithmetic on the length of the day, and so is
-- computed in the client and stored nowhere — these cannot be derived. They
-- come from the lagna, the planetary positions and the judgement of the
-- Nepal Panchanga Nirnayak Samiti, which publishes them once a year. There is
-- no formula, so this is a table an admin fills from the published list rather
-- than a calculation.
--
-- A saait is a window, not an instant: "Baishakh 12, from 09:15" or a whole
-- day. start_time and end_time are therefore nullable — null means the whole
-- day is good.
CREATE TABLE muhurats (
    id           BIGSERIAL   PRIMARY KEY,
    muhurat_date DATE        NOT NULL,
    kind         TEXT        NOT NULL,
    start_time   TIME,
    end_time     TIME,
    note_en      TEXT        NOT NULL DEFAULT '',
    note_ne      TEXT        NOT NULL DEFAULT '',
    source       TEXT        NOT NULL DEFAULT '',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT muhurats_kind_check CHECK (kind IN
        ('marriage', 'bratabandha', 'griha_pravesh', 'annaprashan',
         'business', 'other')),
    -- A window must not end before it starts. Either both times are given or
    -- neither is.
    CONSTRAINT muhurats_window_check CHECK (
        (start_time IS NULL AND end_time IS NULL)
        OR (start_time IS NOT NULL AND end_time IS NOT NULL
            AND end_time > start_time)
    )
);

CREATE INDEX idx_muhurats_date ON muhurats (muhurat_date);
CREATE UNIQUE INDEX idx_muhurats_unique
    ON muhurats (muhurat_date, kind, COALESCE(start_time, '00:00'));

-- Where a saait came from matters more than where a holiday came from, because
-- committees differ. Recording it means a wrong row can be traced.
COMMENT ON COLUMN muhurats.source IS
    'Which published list this came from, e.g. "Nepal Panchanga Nirnayak '
    'Samiti 2083". Left blank it is nobody''s authority but the person who '
    'typed it.';

-- +goose Down
DROP TABLE muhurats;
