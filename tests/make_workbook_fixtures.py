"""Build small, deterministic XLSX/ODS packages for offline integration tests.

Only Python's standard library is used. The packages include actual stored types,
formula records, rich text, repeated ODS rows, and sparse XLSX formatting.
"""
from pathlib import Path
from xml.sax.saxutils import escape, quoteattr
from datetime import date
import json
import sys
import zipfile


def text(v):
    return ('text', v)


def number(v):
    return ('number', str(v))


def tables(variant='valid'):
    profiles = {
        'field': {'type': 'field_collection', 'namespace': 'demo', 'serial_width': 5, 'year_digits': 2, 'year_range': [2000, 2099]},
        'codes': {'type': 'external', 'namespace': 'demo_codes', 'pattern': '^[a-z]+$'},
    }
    meta = [
        ['item', 'value', 'description'],
        ['workbook_id', 'demo_collection', 'Stable server-side workbook identity'],
        ['purpose', 'Offline acceptance fixture', None],
        ['curator', 'Research team', None],
        ['source_reference', 'server-workbook-demo', None],
        ['contract_version', '2.0.0-draft.1', None],
        ['locale', 'en_US', None],
        ['timezone', 'UTC', None],
        ['coordinate_crs', 'EPSG:4326', None],
        ['default_identifier_profile', 'field', None],
        ['identifier_profiles', json.dumps(profiles), None],
        ['coordinate_fields', json.dumps({'data__samples': {'latitude': 'lat', 'longitude': 'lon', 'crs': 'EPSG:4326', 'display_digits': 5}}), None],
    ]
    decl = [['sheet_name', 'key_field', 'key_scope', 'record_unit', 'notes'],
            ['data__samples', 'sample_id', 'row', 'One sampled item', None],
            ['ref__codes', 'code', 'row', 'One controlled code', None]]
    field = [['sheet_name', 'field_name', 'type', 'minimum', 'identifier_profile', 'ref_sheet', 'ref_field'],
             ['ref__codes', 'code', 'text', None, 'codes', None, None],
             ['data__samples', 'reading', 'number', '0', None, None, None],
             ['data__samples', 'category', 'text', None, None, 'ref__codes', 'code'],
             ['data__samples', 'collection_date', 'date', None, None, None, None]]
    sample = [
        ['sample_id', 'lat', 'lon', 'collection_date', 'reading', 'category', 'note', 'optional', 'calc__helper'],
        ['SN26_00001', number('13.63332'), number('-16.3874'), ('date', '2026-09-07'), number(0), 'ok', 'Médina  Djikoye\nquoted "note"\tend', None, ('formula', '#DIV/0!')],
        ['SN26_00002', '13° 30\' 0" N', '16° 12\' 0" W', ('date', '2026-09-08'), number(1.25), 'ok', 'NA', None, ('formula', None)],
    ]
    if variant == 'native_times':
        sample[0].extend(['observation_time', 'elapsed_duration', 'observation_datetime'])
        sample[1].extend([('time', 'PT13H30M'), ('duration', 'PT49H'), ('datetime', '2026-09-07T13:30:00')])
        sample[2].extend([('time', 'PT0H'), ('duration', 'PT0S'), ('datetime', '2026-09-08T00:00:00')])
        field.extend([
            ['data__samples', 'observation_time', 'time', None, None, None, None],
            ['data__samples', 'elapsed_duration', 'duration', None, None, None, None],
            ['data__samples', 'observation_datetime', 'datetime', None, None, None, None]])
    if variant == 'empty':
        sample = sample[:1]
    if variant == 'changed':
        sample[2][4] = number(2.5)
        sample.append(['SN26_00003', number(0), number(0), ('date', '2026-09-09'), None, 'ok', None, None, None])
    if variant == 'cell_error':
        sample[1][4] = ('error', '#VALUE!')
    if variant == 'formula':
        sample[1][4] = ('formula', '2')
    if variant == 'duplicate':
        sample[2][0] = sample[1][0]
    if variant == 'entity':
        sample[2][0] = sample[1][0]
        decl[1][2] = 'entity'
        decl[1][4] = 'Repeated assay observations'
    if variant == 'coordinate':
        sample[1][1] = '-13 N'
    if variant == 'numeric_id':
        sample[1][0] = number('12345678901234567')
    if variant == 'zero_serial':
        sample[1][0] = 'SN26_00000'
    if variant == 'spacer':
        sample.insert(2, [None] * len(sample[0]))
    if variant == 'bad_date':
        sample[1][3] = '2026-02-31'
    if variant == 'whitespace':
        sample[1][0] = ' SN26_00001'
    if variant == 'missing_crs':
        meta = [r for r in meta if r[0] not in ('coordinate_crs', 'coordinate_fields')]
    out = {'meta__readme': meta, 'meta__tables': decl, 'meta__fields': field, 'data__samples': sample,
           'ref__codes': [['code', 'label'], ['ok', 'Valid result']], 'calc__dashboard': [['result'], [('formula', '#DIV/0!')]]}
    if variant == 'unknown_role':
        out['Sheet1'] = [['id'], ['A01']]
    return out


def col(n):
    s = ''
    while n:
        n, r = divmod(n-1, 26)
        s = chr(65+r) + s
    return s


def write_package(path, content):
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        for name, payload in content.items():
            info = zipfile.ZipInfo(name, (2026, 9, 7, 0, 0, 0))
            info.compress_type = zipfile.ZIP_STORED if name == 'mimetype' else zipfile.ZIP_DEFLATED
            z.writestr(info, payload)


def xlsx(path, sheets, variant):
    ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
    relns = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
    shared_strings = []
    content = {'[Content_Types].xml': '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' + ''.join(f'<Override PartName="/xl/worksheets/sheet{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' for i in range(1,len(sheets)+1)) + '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
               '_rels/.rels': f'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="{relns}/officeDocument" Target="xl/workbook.xml"/></Relationships>'}
    names = ''.join(f'<sheet name={quoteattr(name)} sheetId="{i}" r:id="rId{i}"/>' for i, name in enumerate(sheets, 1))
    content['xl/workbook.xml'] = f'<workbook xmlns="{ns}" xmlns:r="{relns}"><workbookPr date1904="{1 if variant == 'date1904' else 0}"/><sheets>{names}</sheets></workbook>'
    rels = ''.join(f'<Relationship Id="rId{i}" Type="{relns}/worksheet" Target="worksheets/sheet{i}.xml"/>' for i in range(1, len(sheets)+1))
    rels += f'<Relationship Id="styles" Type="{relns}/styles" Target="styles.xml"/>'
    content['xl/_rels/workbook.xml.rels'] = f'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">{rels}</Relationships>'
    content['xl/styles.xml'] = f'<styleSheet xmlns="{ns}"><fonts count="1"><font/></fonts><fills count="1"><fill><patternFill patternType="none"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="5"><xf numFmtId="0"/><xf numFmtId="14" applyNumberFormat="1"/><xf numFmtId="21"/><xf numFmtId="46"/><xf numFmtId="22"/></cellXfs></styleSheet>'
    for si, (name, rows) in enumerate(sheets.items(), 1):
        xmlrows = []
        for r, row in enumerate(rows, 1):
            cells = []
            for c, item in enumerate(row, 1):
                if item is None:
                    continue
                kind, value = item if isinstance(item, tuple) else ('text', item)
                ref = f'{col(c)}{r}'
                if kind == 'text' and variant == 'shared_strings':
                    index = len(shared_strings)
                    shared_strings.append(value)
                    xml = f'<c r="{ref}" t="s"><v>{index}</v></c>'
                elif kind == 'text':
                    xml = f'<c r="{ref}" t="inlineStr"><is><t xml:space="preserve">{escape(value)}</t></is></c>'
                elif kind == 'date':
                    serial = (date.fromisoformat(value) - (date(1904, 1, 1) if variant == 'date1904' else date(1899, 12, 30))).days
                    xml = f'<c r="{ref}" s="1"><v>{serial}</v></c>'
                elif kind in ('time', 'duration', 'datetime'):
                    if kind == 'time':
                        serial, style = (13.5 / 24 if value == 'PT13H30M' else 0), 2
                    elif kind == 'duration':
                        serial, style = (49 / 24 if value == 'PT49H' else 0), 3
                    else:
                        serial = (date.fromisoformat(value[:10]) - date(1899, 12, 30)).days + (13.5 / 24 if '13:30' in value else 0)
                        style = 4
                    xml = f'<c r="{ref}" s="{style}"><v>{serial}</v></c>'
                elif kind == 'error':
                    xml = f'<c r="{ref}" t="e"><v>{value}</v></c>'
                elif kind == 'formula':
                    v = '' if value is None else f'<v>{escape(value)}</v>'
                    typ = ' t="e"' if value and value.startswith('#') else ''
                    xml = f'<c r="{ref}"{typ}><f>1/0</f>{v}</c>'
                else:
                    xml = f'<c r="{ref}"><v>{value}</v></c>'
                cells.append(xml)
            xmlrows.append(f'<row r="{r}">{"".join(cells)}</row>')
        xmlrows.append('<row r="5000"><c r="Z5000" s="1"/></row>')
        merge = '<mergeCells count="1"><mergeCell ref="E2:F2"/></mergeCells>' if variant == 'merged' and name == 'data__samples' else ''
        content[f'xl/worksheets/sheet{si}.xml'] = f'<worksheet xmlns="{ns}"><sheetData>{"".join(xmlrows)}</sheetData>{merge}</worksheet>'
    if shared_strings:
        content['xl/sharedStrings.xml'] = f'<sst xmlns="{ns}">' + ''.join(f'<si><r><t xml:space="preserve">{escape(v)}</t></r></si>' for v in shared_strings) + '</sst>'
        content['xl/_rels/workbook.xml.rels'] = content['xl/_rels/workbook.xml.rels'].replace('</Relationships>', f'<Relationship Id="strings" Type="{relns}/sharedStrings" Target="sharedStrings.xml"/></Relationships>')
        content['[Content_Types].xml'] = content['[Content_Types].xml'].replace('</Types>', '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/></Types>')
    write_package(path, content)


def ods(path, sheets, variant):
    ns = 'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2"'
    xmltabs = []
    for name, rows in sheets.items():
        xmlrows = []
        for ri, row in enumerate(rows, 1):
            cells = []
            for ci, item in enumerate(row, 1):
                if item is None:
                    cells.append('<table:table-cell/>')
                    continue
                kind, value = item if isinstance(item, tuple) else ('text', item)
                span = ' table:number-columns-spanned="2"' if variant == 'merged' and name == 'data__samples' and ri == 2 and ci == 5 else ''
                if kind == 'text':
                    # Explicit ODF space/tab/paragraph encodings preserve exact text.
                    value = escape(value).replace('  ', '<text:s text:c="2"/>').replace('\t', '<text:tab/>')
                    body = ''.join(f'<text:p>{line}</text:p>' for line in value.split('\n'))
                    xml = f'<table:table-cell office:value-type="string"{span}>{body}</table:table-cell>'
                elif kind in ('date', 'datetime'):
                    xml = f'<table:table-cell office:value-type="date" office:date-value="{value}"{span}><text:p>{value}</text:p></table:table-cell>'
                elif kind in ('time', 'duration'):
                    xml = f'<table:table-cell office:value-type="time" office:time-value="{value}"{span}/>'
                elif kind == 'error':
                    xml = f'<table:table-cell office:value-type="error"><text:p>{value}</text:p></table:table-cell>'
                elif kind == 'formula':
                    body = '' if value is None else f'<text:p>{escape(value)}</text:p>'
                    xml = f'<table:table-cell table:formula="of:=1/0"{span}>{body}</table:table-cell>'
                else:
                    xml = f'<table:table-cell office:value-type="float" office:value="{value}"{span}/>'
                cells.append(xml)
            cells.append('<table:table-cell table:number-columns-repeated="16000"/>')
            xmlrows.append(f'<table:table-row>{"".join(cells)}</table:table-row>')
        xmlrows.append('<table:table-row table:number-rows-repeated="1000000"><table:table-cell table:number-columns-repeated="16000"/></table:table-row>')
        xmltabs.append(f'<table:table table:name={quoteattr(name)}>{"".join(xmlrows)}</table:table>')
    content = {'mimetype': 'application/vnd.oasis.opendocument.spreadsheet',
               'content.xml': f'<?xml version="1.0" encoding="UTF-8"?><office:document-content {ns} office:version="1.3"><office:body><office:spreadsheet>{"".join(xmltabs)}</office:spreadsheet></office:body></office:document-content>',
               'META-INF/manifest.xml': '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3"><manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/><manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/></manifest:manifest>'}
    write_package(path, content)


def main(directory):
    directory.mkdir(parents=True, exist_ok=True)
    for variant in ['valid', 'changed', 'formula', 'duplicate', 'entity', 'coordinate', 'numeric_id', 'zero_serial', 'spacer', 'bad_date', 'whitespace', 'missing_crs', 'unknown_role', 'merged', 'native_times', 'date1904', 'shared_strings', 'empty', 'cell_error']:
        for extension, writer in [('xlsx', xlsx), ('ods', ods)]:
            writer(directory / f'{variant}.{extension}', tables(variant), variant)


if __name__ == '__main__':
    main(Path(sys.argv[1]))
