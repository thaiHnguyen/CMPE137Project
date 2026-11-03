import 'package:server/browse/paging.dart';
import 'package:server/dao/title_dao.dart';
import 'package:test/test.dart';

void main() {
  group('parsePaging', () {
    test('defaults to page 1 with 20 titles', () {
      final paging = parsePaging({})!;
      expect(paging.page, 1);
      expect(paging.limit, 20);
      expect(paging.offset, 0);
    });

    test('works out the offset', () {
      expect(parsePaging({'page': '3', 'limit': '10'})!.offset, 20);
    });

    test('rejects bad values', () {
      for (final bad in ['0', '-1', 'abc', '1.5', '+5', '0x10', '']) {
        expect(parsePaging({'page': bad}), isNull, reason: 'page=$bad');
        expect(parsePaging({'limit': bad}), isNull, reason: 'limit=$bad');
      }
      expect(parsePaging({'limit': '51'}), isNull);
      expect(parsePaging({'page': '100001'}), isNull);
    });
  });

  group('parseId', () {
    test('accepts positive whole numbers only', () {
      expect(parseId('42'), 42);
      for (final bad in ['0', '-1', 'abc', '0x10', '99999999999999999999']) {
        expect(parseId(bad), isNull, reason: bad);
      }
    });
  });

  group('escapeLike', () {
    test('escapes LIKE wildcards', () {
      expect(TitleDao.escapeLike('100%'), r'100\%');
      expect(TitleDao.escapeLike('a_b'), r'a\_b');
      expect(TitleDao.escapeLike(r'a\b'), r'a\\b');
    });
  });
}
