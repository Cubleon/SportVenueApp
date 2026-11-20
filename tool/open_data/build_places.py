"""Builds assets/data/moscow_places.json from data.mos.ru exports.

Usage:
    python3 tool/open_data/build_places.py data-893-*.json data-1251-*.json

Inputs are the JSON exports of «Площадки спортивные универсальные» (893) and
«Площадки спортивные универсальные в парках» (1251) from data.mos.ru, in the
portal's cp1251 encoding. Licence: CC BY 4.0, the source is credited in the
app. Paid courts are left out: the app shows these as free, unbooked places.
Names of officials, e-mails and phones are not copied.
"""
import json
import sys
from collections import Counter

MONTHS = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля',
          'августа', 'сентября', 'октября', 'ноября', 'декабря']
DAYS = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота',
        'воскресенье']
SURFACES = {
    'заливное покрытие': 'rubber',
    'специальное покрытие': 'rubber',
    'рулонное покрытие': 'rubber',
    'газонное покрытие (искусственное)': 'artificial_grass',
    'газонное покрытие (натуральное)': 'grass',
    'асфальтовое, бетонное покрытие': 'asphalt',
}


def sport(name):
    name = name.lower()
    for word, sport_id in (('футбол', 'football'), ('баскетбол', 'basketball'),
                           ('стритбол', 'basketball'), ('волейбол', 'volleyball'),
                           ('бадминтон', 'badminton')):
        if word in name:
            return sport_id
    return 'universal'


def season(raw):
    try:
        start, end = raw.split('-')
        (d1, m1), (d2, m2) = (map(int, start.split('.')), map(int, end.split('.')))
    except ValueError:
        return ''
    if (d1, m1) == (1, 1) and (d2, m2) == (31, 12):
        return ''
    if m2 == (m1 - 2) % 12 + 1 or (m1, m2) == (9, 8):  # a full year from September
        return ''
    if not (1 <= m1 <= 12 and 1 <= m2 <= 12):
        return ''
    return f'{d1} {MONTHS[m1 - 1]} – {d2} {MONTHS[m2 - 1]}'


def hours(days):
    by_day = {d['DayOfWeek']: d['Hours'] for d in days}
    common = Counter(by_day.get(d, '') for d in DAYS).most_common(1)[0][0]
    return common.replace('-', '–')


def kind(record, source):
    if source == 'park':
        return 'park'
    owner = record['ObjectName'].lower()
    if 'образовательн' in owner or 'edu.mos.ru' in (record.get('Email') or ''):
        return 'school'
    return 'yard'


NAMES = {
    'football': 'Футбольная площадка',
    'basketball': 'Баскетбольная площадка',
    'volleyball': 'Волейбольная площадка',
    'badminton': 'Площадка для бадминтона',
    'universal': 'Универсальная площадка',
}


def describe(where, park, hours_text, season_text, dressing, toilet):
    parts = []
    if where == 'school':
        parts.append('На территории школы: вход может быть закрыт, уточните на месте.')
    elif where == 'park':
        parts.append(f'В парке: {park}.')
    if hours_text:
        parts.append(f'Открыта {hours_text}' + (f', сезон {season_text}.' if season_text else ', круглый год.'))
    extras = [w for w, has in (('раздевалка', dressing), ('туалет', toilet)) if has]
    if extras:
        parts.append(', '.join(extras).capitalize() + '.')
    parts.append('Данные: Портал открытых данных Москвы.')
    return ' '.join(parts)


def rows(path, source):
    with open(path, encoding='cp1251') as f:
        data = json.load(f)
    for r in data:
        if r.get('Paid') == 'платно':
            continue
        lon, lat = r['geoData']['coordinates']
        where, sport_id = kind(r, source), sport(r['NameSummer'])
        hours_text, season_text = hours(r['WorkingHoursSummer']), season(r.get('UsagePeriodSummer', ''))
        dressing, toilet = r.get('HasDressingRoom') == 'да', r.get('HasToilet') == 'да'
        yield [
            r['global_id'],
            where,
            sport_id,
            NAMES[sport_id] + (' при школе' if where == 'school' else ''),
            r['Address'],
            r['District'],
            round(lat, 6),
            round(lon, 6),
            SURFACES.get(r.get('SurfaceTypeSummer', ''), 'other'),
            0 if r.get('Lighting', '') in ('', 'без дополнительного освещения') else 1,
            describe(where, r['ObjectName'], hours_text, season_text, dressing, toilet),
        ]


def main(paths):
    out, seen = [], set()
    for path in paths:
        source = 'park' if 'data-1251' in path else 'city'
        for row in rows(path, source):
            if row[0] in seen:
                continue
            seen.add(row[0])
            out.append(row)
    doc = {
        'source': 'Портал открытых данных Правительства Москвы, data.mos.ru (CC BY 4.0)',
        'fields': ['id', 'kind', 'sport', 'name', 'address', 'district', 'lat', 'lon',
                   'surface', 'lighting', 'description'],
        'rows': out,
    }
    with open('assets/data/moscow_places.json', 'w', encoding='utf-8') as f:
        json.dump(doc, f, ensure_ascii=False, separators=(',', ':'))
    print(len(out), Counter(r[1] for r in out), Counter(r[2] for r in out))


if __name__ == '__main__':
    main(sys.argv[1:])
