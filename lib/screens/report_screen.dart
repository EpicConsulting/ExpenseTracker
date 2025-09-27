import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import '../models/expense.dart';
import '../models/category.dart';
import '../models/payer.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../providers/payer_provider.dart';
import '../widgets/app_drawer.dart';

class ReportScreen extends StatefulWidget {
  static const routeName = '/report';

  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = [];

  // Payer filter
  final Payer _allPayersOption = Payer(id: -1, name: 'All Payers');
  List<Payer> _payerFilterOptions = [];
  Payer? _selectedPayerFilter;

  bool _isLoading = true;

  Map<int, double> _categoryTotals = {};
  List<BarChartGroupData> _barGroups = [];
  List<PieChartSectionData> _pieChartSections = [];
  double _maxYValue = 0;
  double _totalAnnualExpenses = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialDataAndReport();
  }

  Future<void> _loadInitialDataAndReport() async {
    developer.log('Loading initial data for ReportScreen...', name: 'ReportScreen');
    setState(() {
      _isLoading = true;
    });

    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final payerProvider = Provider.of<PayerProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);

      await categoryProvider.fetchCategories();

      final years = await expenseProvider.getAvailableExpenseYears();
      if (mounted) {
        setState(() {
          _availableYears = years.isNotEmpty ? years : [DateTime.now().year];
          if (!_availableYears.contains(_selectedYear)) {
            _selectedYear = _availableYears.first;
          }
        });
      }

      await payerProvider.fetchPayers();
      if (mounted) {
        setState(() {
          _payerFilterOptions = [
            _allPayersOption,
            ...payerProvider.payers,
          ];
          _selectedPayerFilter = _allPayersOption;
        });
      }

      await _loadReportData();
    } catch (e) {
      developer.log('Error loading initial report data: $e', name: 'ReportScreen', error: e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReportData() async {
    developer.log(
      'Loading report data for year: $_selectedYear, payer: ${_selectedPayerFilter?.name}',
      name: 'ReportScreen',
    );

    if (!mounted) {
      developer.log('ReportScreen not mounted during _loadReportData.', name: 'ReportScreen');
      return;
    }

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);

    List<Expense> filteredExpenses;
    if (_selectedPayerFilter != null && _selectedPayerFilter!.id != -1) {
      filteredExpenses = expenseProvider.expenses
          .where((exp) => exp.date.year == _selectedYear && exp.payerId == _selectedPayerFilter!.id)
          .toList();
    } else {
      filteredExpenses =
          expenseProvider.expenses.where((exp) => exp.date.year == _selectedYear).toList();
    }

    // Monthly totals (kept internally if you want to use later)
    final tempMonthlyTotals = <int, double>{for (var m = 1; m <= 12; m++) m: 0.0};
    for (var exp in filteredExpenses) {
      tempMonthlyTotals[exp.date.month] =
          (tempMonthlyTotals[exp.date.month] ?? 0.0) + exp.amount;
    }

    // Category totals
    final tempCategoryTotals = <int, double>{};
    for (var exp in filteredExpenses) {
      final cid = exp.categoryId ?? -1;
      tempCategoryTotals.update(cid, (v) => v + exp.amount, ifAbsent: () => exp.amount);
    }

    // Bar chart preparation
    final tempBarGroups = <BarChartGroupData>[];
    double tempMaxYValue = 0;
    for (int i = 1; i <= 12; i++) {
      final amt = tempMonthlyTotals[i] ?? 0.0;
      if (amt > tempMaxYValue) tempMaxYValue = amt;
      tempBarGroups.add(
        BarChartGroupData(
          x: i,
            barRods: [
              BarChartRodData(
                toY: amt,
                color: Theme.of(context).primaryColor,
                width: 15,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
        ),
      );
    }
    tempMaxYValue = (tempMaxYValue * 1.2).ceilToDouble();
    if (tempMaxYValue < 100) tempMaxYValue = 100;

    // Pie chart
    final tempPieChartSections = <PieChartSectionData>[];
    final tempTotalAnnualExpenses =
        filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    if (tempCategoryTotals.isEmpty || tempTotalAnnualExpenses == 0) {
      tempPieChartSections.add(
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          title: 'No Data',
          radius: 60,
          titleStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    } else {
      tempCategoryTotals.entries.where((e) => e.value > 0).forEach((entry) {
        final category = categoryProvider.categories.firstWhere(
          (cat) => cat.id == entry.key,
          orElse: () => Category(
            id: -1,
            name: 'Unknown Category',
            // Replace deprecated .value with ARGB literal
            color: 0xFF9E9E9E,
          ),
        );
        final pct = (entry.value / tempTotalAnnualExpenses) * 100;

        Color sectionColor;
        if (category.color != null) {
          sectionColor = Color(category.color!);
        } else {
          sectionColor = _getCategoryColor(category.id!);
        }

        tempPieChartSections.add(
          PieChartSectionData(
            color: sectionColor,
            value: entry.value,
            title: '${category.name}\n${pct.toStringAsFixed(1)}%',
            radius: 80,
            titleStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget:
                category.id == -1 ? const Icon(Icons.help_outline, color: Colors.white, size: 18) : null,
          ),
        );
      });
    }

    if (mounted) {
      setState(() {
        _categoryTotals = tempCategoryTotals;
        _barGroups = tempBarGroups;
        _maxYValue = tempMaxYValue;
        _pieChartSections = tempPieChartSections;
        _totalAnnualExpenses = tempTotalAnnualExpenses;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense Report')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Report'),
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Select Year',
                  border: OutlineInputBorder(),
                ),
                items: _availableYears
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (year) {
                  if (year != null) {
                    setState(() => _selectedYear = year);
                    _loadReportData();
                  }
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Payer>(
                value: _selectedPayerFilter,
                decoration: const InputDecoration(
                  labelText: 'Filter by Payer',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: _allPayersOption,
                    child: Text(_allPayersOption.name),
                  ),
                  ..._payerFilterOptions
                      .where((p) => p.id != -1)
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
                ],
                onChanged: (payer) {
                  if (payer != null) {
                    setState(() => _selectedPayerFilter = payer);
                    _loadReportData();
                  }
                },
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Total Expenses in $_selectedYear:',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${_totalAnnualExpenses.toStringAsFixed(2)} ฿',
                          style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'Monthly Expenses in $_selectedYear',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 250,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                    child: BarChart(
                      BarChartData(
                        barGroups: _barGroups,
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 20,
                              getTitlesWidget: (value, meta) {
                                final monthName =
                                    DateFormat.MMM().format(DateTime(2023, value.toInt()));
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 4,
                                  child: Text(
                                    monthName,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 4,
                                  child: Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _maxYValue,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Category Breakdown in $_selectedYear',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 250,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: PieChart(
                      PieChartData(
                        sections: _pieChartSections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              // Add interactive behavior if desired
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Category Legend',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ..._categoryTotals.entries.where((e) => e.value > 0).map((entry) {
                final category = Provider.of<CategoryProvider>(context).categories.firstWhere(
                      (cat) => cat.id == entry.key,
                  orElse: () => Category(
                    id: -1,
                    name: 'Unknown Category',
                    // Replace deprecated .value with ARGB literal
                    color: 0xFF9E9E9E,
                  ),
                );

                Color legendColor;
                if (category.color != null) {
                  legendColor = Color(category.color!);
                } else {
                  legendColor = _getCategoryColor(category.id!);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        color: legendColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${category.name}: ${entry.value.toStringAsFixed(2)} ฿'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(int categoryId) {
    switch (categoryId % 5) {
      case 0:
        return Colors.blue.shade700;
      case 1:
        return Colors.green.shade700;
      case 2:
        return Colors.orange.shade700;
      case 3:
        return Colors.purple.shade700;
      case 4:
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }
}