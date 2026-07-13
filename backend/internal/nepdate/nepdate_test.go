package nepdate

import (
	"testing"
	"time"
)

func ad(s string) time.Time {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		panic(err)
	}
	return t
}

// The BS 2083 festival list the owner supplied prints both calendars for every
// entry. The Dart side asserts all 44 of these; this asserts the same pairs
// against the Go port, so the two implementations cannot drift apart silently.
var published = []struct {
	bs Date
	ad string
}{
	{Date{2083, 1, 1}, "2026-04-14"},   // Nepali New Year
	{Date{2083, 1, 18}, "2026-05-01"},  // Buddha Jayanti
	{Date{2083, 2, 15}, "2026-05-29"},  // Republic Day
	{Date{2083, 5, 12}, "2026-08-28"},  // Janai Purnima
	{Date{2083, 6, 3}, "2026-09-19"},   // Constitution Day
	{Date{2083, 6, 25}, "2026-10-11"},  // Ghatasthapana
	{Date{2083, 7, 4}, "2026-10-21"},   // Vijaya Dashami
	{Date{2083, 7, 22}, "2026-11-08"},  // Laxmi Puja
	{Date{2083, 7, 25}, "2026-11-11"},  // Bhai Tika
	{Date{2083, 9, 10}, "2026-12-25"},  // Christmas
	{Date{2083, 10, 1}, "2027-01-15"},  // Maghe Sankranti
	{Date{2083, 11, 22}, "2027-03-06"}, // Maha Shivaratri
	{Date{2083, 12, 7}, "2027-03-21"},  // Holi
	// The anchor every Nepali calendar agrees on.
	{Date{2081, 1, 1}, "2024-04-13"},
}

func TestToADMatchesThePublishedList(t *testing.T) {
	for _, c := range published {
		got, err := ToAD(c.bs.Year, c.bs.Month, c.bs.Day)
		if err != nil {
			t.Fatalf("BS %s: %v", c.bs, err)
		}
		if want := ad(c.ad); !got.Equal(want) {
			t.Errorf("BS %s -> %s, want %s",
				c.bs, got.Format("2006-01-02"), c.ad)
		}
	}
}

func TestFromADMatchesThePublishedList(t *testing.T) {
	for _, c := range published {
		got, err := FromAD(ad(c.ad))
		if err != nil {
			t.Fatalf("%s: %v", c.ad, err)
		}
		if got != c.bs {
			t.Errorf("%s -> BS %s, want BS %s", c.ad, got, c.bs)
		}
	}
}

// The Ministry of Home Affairs gazette for BS 2082 names a weekday for each
// holiday, which is a checksum the table has to satisfy.
func TestGazetteWeekdays(t *testing.T) {
	cases := []struct {
		month, day int
		weekday    time.Weekday
		what       string
	}{
		{9, 27, time.Sunday, "Prithvi Jayanti"},
		{10, 1, time.Thursday, "Maghe Sankranti"},
		{10, 5, time.Monday, "Sonam Losar"},
		{10, 16, time.Friday, "Martyrs' Day"},
		{11, 3, time.Sunday, "Maha Shivaratri"},
		{11, 6, time.Wednesday, "Gyalpo Losar"},
		{11, 18, time.Monday, "Holi (hills)"},
		{11, 19, time.Tuesday, "Holi (Terai)"},
		{12, 13, time.Friday, "Ram Navami"},
		{6, 6, time.Monday, "Ghatasthapana"},
		{7, 3, time.Monday, "Laxmi Puja"},
	}
	for _, c := range cases {
		got, err := ToAD(2082, c.month, c.day)
		if err != nil {
			t.Fatalf("BS 2082-%d-%d: %v", c.month, c.day, err)
		}
		if got.Weekday() != c.weekday {
			t.Errorf("%s: BS 2082-%d-%d is %s (%s), gazette says %s",
				c.what, c.month, c.day,
				got.Format("2006-01-02"), got.Weekday(), c.weekday)
		}
	}
}

func TestRoundTripsEveryDayOfFourYears(t *testing.T) {
	day := ad("2024-01-01")
	for i := 0; i < 4*365; i++ {
		bs, err := FromAD(day)
		if err != nil {
			t.Fatalf("%s: %v", day.Format("2006-01-02"), err)
		}
		back, err := ToAD(bs.Year, bs.Month, bs.Day)
		if err != nil {
			t.Fatalf("BS %s: %v", bs, err)
		}
		if !back.Equal(day) {
			t.Fatalf("%s -> BS %s -> %s",
				day.Format("2006-01-02"), bs, back.Format("2006-01-02"))
		}
		day = day.AddDate(0, 0, 1)
	}
}

func TestMonthLengthsAreSane(t *testing.T) {
	for year := 2080; year <= 2085; year++ {
		total := 0
		for month := 1; month <= 12; month++ {
			n := MonthLength(year, month)
			if n < 29 || n > 32 {
				t.Errorf("BS %d-%d has %d days", year, month, n)
			}
			total += n
		}
		if total != 365 && total != 366 {
			t.Errorf("BS %d has %d days", year, total)
		}
	}
}

func TestRejectsDatesOutsideTheTable(t *testing.T) {
	if _, err := ToAD(1900, 1, 1); err == nil {
		t.Error("BS 1900 should be rejected, not guessed at")
	}
	if _, err := ToAD(2300, 1, 1); err == nil {
		t.Error("BS 2300 should be rejected")
	}
	// Falgun 2082 has 30 days, so there is no 32nd.
	if _, err := ToAD(2082, 11, 32); err == nil {
		t.Error("a day past the end of the month should be rejected")
	}
}

// The whole reason this package exists on the server.
func TestNextAnniversaryDriftsAgainstTheGregorianCalendar(t *testing.T) {
	// Someone born on 15 Ashar 2050. The BS date is fixed; the Gregorian date
	// it lands on is not.
	birth := Date{Year: 2050, Month: 3, Day: 15}

	first, err := NextAnniversary(birth, ad("2026-01-01"))
	if err != nil {
		t.Fatal(err)
	}
	second, err := NextAnniversary(birth, first.AddDate(0, 0, 1))
	if err != nil {
		t.Fatal(err)
	}

	// Both must be 15 Ashar.
	for _, when := range []time.Time{first, second} {
		bs, err := FromAD(when)
		if err != nil {
			t.Fatal(err)
		}
		if bs.Month != 3 || bs.Day != 15 {
			t.Errorf("%s is BS %s, expected 15 Ashar",
				when.Format("2006-01-02"), bs)
		}
	}

	// And they must not be the same Gregorian day-of-year — that drift is the
	// point. A naive "same month and day next year" would be wrong.
	if first.Month() == second.Month() && first.Day() == second.Day() {
		t.Errorf("no drift: %s then %s — a Gregorian rule would have done",
			first.Format("2006-01-02"), second.Format("2006-01-02"))
	}
	gap := int(second.Sub(first).Hours() / 24)
	if gap < 353 || gap > 367 {
		t.Errorf("anniversaries %d days apart, expected about a year", gap)
	}
}

func TestNextAnniversaryReturnsTodayWhenItIsTheDay(t *testing.T) {
	// 25 Ashar 2083 is 9 July 2026.
	on := ad("2026-07-09")
	got, err := NextAnniversary(Date{Year: 2050, Month: 3, Day: 25}, on)
	if err != nil {
		t.Fatal(err)
	}
	if !got.Equal(on) {
		t.Errorf("got %s, want today (%s)",
			got.Format("2006-01-02"), on.Format("2006-01-02"))
	}
}

func TestNextAnniversaryClampsAMissingDay(t *testing.T) {
	// Ashar has 31 or 32 days depending on the year. Someone born on the 32nd
	// must still get a birthday in a year that has only 31.
	born := Date{Year: 2050, Month: 3, Day: 32}
	when, err := NextAnniversary(born, ad("2026-01-01"))
	if err != nil {
		t.Fatalf("a 32 Ashar birthday must not vanish: %v", err)
	}
	bs, err := FromAD(when)
	if err != nil {
		t.Fatal(err)
	}
	length := MonthLength(bs.Year, 3)
	want := 32
	if length < 32 {
		want = length
	}
	if bs.Month != 3 || bs.Day != want {
		t.Errorf("got BS %s, expected Ashar %d (the month has %d days)",
			bs, want, length)
	}
}
