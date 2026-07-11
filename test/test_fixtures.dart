import 'package:game_credit_profit_manager/shared/models/credit_package.dart';
import 'package:game_credit_profit_manager/shared/models/product.dart';

const defaultProduct = Product(
  id: 'product_100_gems',
  name: '100 جوهرة',
  gemsPerUnit: 100,
  creditPerUnit: 240,
  salePriceDzd: 350,
);

const defaultPackages = <CreditPackage>[
  CreditPackage(
    id: 'pkg_110',
    name: 'باقة 110 رصيد',
    priceDzd: 150,
    credit: 110,
    validityHours: 24,
  ),
  CreditPackage(
    id: 'pkg_200',
    name: 'باقة 200 رصيد',
    priceDzd: 250,
    credit: 200,
    validityHours: 24,
  ),
  CreditPackage(
    id: 'pkg_400',
    name: 'باقة 400 رصيد',
    priceDzd: 500,
    credit: 400,
    validityHours: 168,
  ),
  CreditPackage(
    id: 'pkg_900',
    name: 'باقة 900 رصيد',
    priceDzd: 1000,
    credit: 900,
    validityHours: 168,
  ),
  CreditPackage(
    id: 'pkg_2000',
    name: 'باقة 2000 رصيد',
    priceDzd: 2000,
    credit: 2000,
    validityHours: 360,
  ),
  CreditPackage(
    id: 'pkg_3000',
    name: 'باقة 3000 رصيد',
    priceDzd: 3000,
    credit: 3000,
    validityHours: 720,
  ),
];
