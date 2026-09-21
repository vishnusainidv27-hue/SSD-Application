import 'package:admin_mobile_app/utils/customer_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_shared/ssd_shared.dart';

CustomerModel _c(
  String id,
  String name, {
  String mobile = '9999999999',
  String society = 'Green Valley',
  String block = 'A',
  String flat = '101',
  List<MilkType> milk = const [MilkType.cow],
  bool active = true,
}) =>
    CustomerModel(
      id: id,
      name: name,
      mobile: mobile,
      societyName: society,
      blockName: block,
      floor: '1',
      flatNumber: flat,
      landmark: '',
      finalAddress: '',
      milkTypes: milk,
      active: active,
    );

void main() {
  group('CustomerModel.buildFinalAddress', () {
    test('joins all fields in flat → landmark order', () {
      expect(
        CustomerModel.buildFinalAddress(
          societyName: 'Green Valley Society',
          blockName: 'C',
          floor: '4',
          flatNumber: '402',
          landmark: 'Near City Hospital',
        ),
        'Flat 402, Floor 4, Block C, Green Valley Society, Near City Hospital',
      );
    });

    test('skips blank fields', () {
      expect(
        CustomerModel.buildFinalAddress(
          societyName: 'Green Valley',
          blockName: ' ',
          floor: '',
          flatNumber: '12',
          landmark: '',
        ),
        'Flat 12, Green Valley',
      );
    });
  });

  group('filterCustomers', () {
    final customers = [
      _c('1', 'Asha Rao', mobile: '9811111111', flat: '402'),
      _c('2', 'Ravi Kumar',
          mobile: '9822222222',
          society: 'Lake View',
          block: 'B',
          milk: [MilkType.buffalo],
          active: false),
      _c('3', 'Meena Shah',
          mobile: '9833333333',
          society: 'Lake View',
          milk: [MilkType.cow, MilkType.buffalo]),
    ];

    List<String> ids(List<CustomerModel> l) => [for (final c in l) c.id];

    test('no filters returns everyone', () {
      expect(ids(filterCustomers(customers)), ['1', '2', '3']);
    });

    test('search matches name, mobile, society, block and flat', () {
      expect(ids(filterCustomers(customers, query: 'ravi')), ['2']);
      expect(ids(filterCustomers(customers, query: '98333')), ['3']);
      expect(ids(filterCustomers(customers, query: 'lake')), ['2', '3']);
      expect(ids(filterCustomers(customers, query: '402')), ['1']);
      expect(ids(filterCustomers(customers, query: ' B ')), ['2']);
    });

    test('society filter is exact and case-insensitive', () {
      expect(ids(filterCustomers(customers, society: 'lake view')), ['2', '3']);
    });

    test('milk type filter includes customers with Both', () {
      expect(ids(filterCustomers(customers, milkType: MilkType.buffalo)),
          ['2', '3']);
      expect(ids(filterCustomers(customers, milkType: MilkType.cow)),
          ['1', '3']);
    });

    test('status filter', () {
      expect(
          ids(filterCustomers(customers, status: CustomerStatusFilter.inactive)),
          ['2']);
      expect(
          ids(filterCustomers(customers, status: CustomerStatusFilter.active)),
          ['1', '3']);
    });

    test('filters combine', () {
      expect(
          ids(filterCustomers(customers,
              query: 'a', society: 'Lake View', milkType: MilkType.cow)),
          ['3']);
    });
  });
}
