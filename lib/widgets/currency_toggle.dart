import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';

class CurrencyToggle extends StatelessWidget {
  const CurrencyToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    return Row(
      children: [
        Text(currencyProvider.currency == 'USD' ? ' 24' : ''),
        Switch(
          value: currencyProvider.currency == 'USD',
          onChanged: (val) {
            currencyProvider.setCurrency(val ? 'USD' : 'VES');
          },
        ),
        const Text('USD'),
      ],
    );
  }
}
