"""Synthetic declaration and parser regressions; never source-server exports."""
from pathlib import Path
import json
import sys
from make_workbook_fixtures import tables, xlsx, ods, write_package


def main(directory):
    directory.mkdir(parents=True, exist_ok=True)
    def save(name, book):
        for ext, writer in [('xlsx', xlsx), ('ods', ods)]:
            writer(directory / (name + '.' + ext), book, name)
    def rule(book, field, **kwargs):
        rows = book['meta__fields']
        for key in kwargs:
            if key not in rows[0]:
                rows[0].append(key)
        for row in rows[1:]:
            row.extend([None] * (len(rows[0])-len(row)))
        row = next((r for r in rows[1:] if r[:2] == ['data__samples', field]), None)
        if row is None:
            row = ['data__samples', field] + [None] * (len(rows[0])-2)
            rows.append(row)
        for key, value in kwargs.items():
            row[rows[0].index(key)] = value
    cases = {
        'bounds_no_type': dict(type=None, minimum='0'),
        'bounds_text': dict(type='text', minimum='0'),
        'bounds_inf': dict(minimum='Inf'),
        'bounds_reverse': dict(minimum='2', maximum='1'),
        'bounds_vector': dict(minimum='[0,1]'),
        'bounds_valid': dict(minimum='0', maximum='1.25'),
        'bad_type': dict(type='numbre'),
        'bad_required': dict(required='TRUE'),
        'vocab_empty': dict(allowed_values='[]'),
        'vocab_object': dict(allowed_values='{}'),
        'vocab_nested': dict(allowed_values='[[0]]'),
        'vocab_null': dict(allowed_values='[null]'),
        'vocab_mixed': dict(allowed_values='[0,"1.25"]'),
        'missing_object': dict(missing_codes='{}'),
        'vocab_valid': dict(allowed_values='[0,1.25]'),
    }
    for case, kwargs in cases.items():
        for shape in ['rows', 'empty', 'missing']:
            book = tables('empty' if shape == 'empty' else 'valid')
            if shape == 'missing':
                for row in book['data__samples'][1:]: row[4] = None
            rule(book, 'reading', **kwargs)
            save(case + '_' + shape, book)
    for typ, literal in [('date','2026-09-07'), ('datetime','2026-09-07T12:30:00Z'), ('time','12:30'), ('duration','PT49H'), ('partial_date','2026-09')]:
        for mode in ['declared', 'undeclared', 'required', 'blank', 'iso']:
            book = tables()
            book['data__samples'][0].append('historical')
            for row in book['data__samples'][1:]: row.append(None if mode == 'blank' else literal if mode == 'iso' else 'NA')
            rule(book, 'historical', type=typ, missing_codes='["NA"]' if mode in ['declared','required'] else None, required='true' if mode == 'required' else None)
            save('temporal_' + typ + '_' + mode, book)
    for label, digits, width, years, ids, empty in [
        ('year_four',4,5,[1850,2026],['SN2026_00001','SN1850_00002'],False),
        ('year_outside',4,5,[1850,2026],['SN1849_00001','SN2027_00002'],False),
        ('year_ambiguous',2,5,[1900,2000],None,True),
        ('year_century',2,5,[1950,2049],None,False),
        ('year_bad_range',4,5,[1850.5,2026],None,True),
        ('year_object',4,5,{'a':1850,'b':2026},None,True),
        ('year_huge',4,5,[0,10000],None,True),
        ('year_bad_width',4,1.5,[1850,2026],None,True),
        ('year_bad_digits',[4],5,[1850,2026],None,True),
        ('year_empty_digits',[],5,[1850,2026],None,True),
        ('year_null_width',4,None,[1850,2026],None,True),
    ]:
        book = tables('empty' if empty else 'valid')
        meta = next(r for r in book['meta__readme'] if r[0]=='identifier_profiles')
        profiles = json.loads(meta[1]); profiles['field'].update(year_digits=digits, serial_width=width, year_range=years)
        meta[1] = json.dumps(profiles)
        if ids:
            for row, value in zip(book['data__samples'][1:],ids): row[0]=value
        save(label,book)
    book=tables(); rule(book,'sample_id',missing_codes='["SN26_00001"]'); save('missing_key_code',book)
    book=tables(); book['data__samples'][1][0]=None; save('missing_key',book)
    book=tables('empty'); save('no_coordinates',book)
    book=tables('entity'); book['data__other']= [row[:] for row in book['data__samples']]
    book['meta__tables'].append(['data__other','sample_id','entity','Repeated measurements','Synthetic second table'])
    save('two_tables',book)
    book['data__other'][1][1:3] = [('number','14.5'), ('number','-17.2')]
    book['data__other'][2][1:3] = [('number','14.6'), ('number','-17.3')]
    save('two_tables_fresh',book)
    book=tables();book['data__samples'][0].append('event_time')
    for row in book['data__samples'][1:]: row.append('12:30')
    book['meta__readme']=[r for r in book['meta__readme'] if r[0]!='timezone']
    rule(book,'event_time',type='time');save('temporal_no_zone',book)
    book=tables();book['data__samples'][1][3]='2026-02-31';save('temporal_bad_date',book)
    book=tables();book['data__samples'][0].append('event_datetime')
    for row in book['data__samples'][1:]: row.append('09/08/26 12:30')
    rule(book,'event_datetime',type='datetime');save('temporal_ambiguous',book)
    book=tables();rule(book,'reading',missing_codes='[]');save('missing_empty',book)
    book=tables();rule(book,'reading',allowed_values='[1]');save('vocab_disallowed',book)
    book=tables();rule(book,'category',allowed_values='[]');save('vocab_empty_reference',book)
    xlsx(directory/'xlsx_exact.xlsx',{'calc__x': [[('number','1')]*10 for _ in range(10)]},'exact')
    xlsx(directory/'xlsx_over.xlsx',{'calc__x': [[('number','1')]*10 for _ in range(11)]},'over')
    # Small ODS encodings: no test allocates an oversized grid.
    cell='<table:table-cell office:value-type="float" office:value="1"/>'
    formula='<table:table-cell table:formula="of:=1"/>'
    cases={
        'ods_two_cells': (100,cell+cell,'data__x'),
        'ods_groups': (20,cell.replace('/>',' table:number-columns-repeated="3"/>')*2,'data__x'),
        'ods_formula': (100,formula+formula,'data__x'),
        'ods_excluded': (100,cell+cell,'calc__x'),
        'ods_exact': (50,cell+cell,'data__x'),
        'ods_blank': (1000000,'<table:table-cell table:number-columns-repeated="16000"/>','data__x'),
        'ods_overflow': ('999999999999999999999',cell,'data__x'),
        'ods_fraction': ('1.5',cell,'data__x'),
        'ods_index_overflow': (1,'<table:table-cell table:number-columns-repeated="2147483647"/>'+cell,'data__x'),
        'ods_zero': (0,cell,'data__x'),
    }
    ns='xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2"'
    for name,(nr,cells,sheet) in cases.items():
        payload=f'<office:document-content {ns}><office:body><office:spreadsheet><table:table table:name="{sheet}"><table:table-row table:number-rows-repeated="{nr}">{cells}</table:table-row></table:table></office:spreadsheet></office:body></office:document-content>'
        write_package(directory/(name+'.ods'),{'content.xml':payload})

if __name__=='__main__': main(Path(sys.argv[1]))
