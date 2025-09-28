import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import '../models/category.dart';
import '../models/payer.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../providers/payer_provider.dart';
import '../widgets/app_drawer.dart';

enum ReportRange { year, month }
enum MonthGranularity { weekly, daily }

class ReportScreen extends StatefulWidget {
  static const routeName = '/report';
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth;
  ReportRange _range = ReportRange.year;
  MonthGranularity _monthGranularity = MonthGranularity.weekly;

  List<int> _availableYears = [];
  final Payer _allPayersOption = Payer(id: -1, name: 'All Payers');
  List<Payer> _payerFilterOptions = [];
  Payer? _selectedPayerFilter;
  bool _isLoading = true;

  Map<int, double> _categoryTotals = {};
  List<BarChartGroupData> _barGroups = [];
  List<PieChartSectionData> _pieChartSections = [];
  double _maxYValue = 0;
  double _totalPeriodExpenses = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialDataAndReport();
  }

  Future<void> _loadInitialDataAndReport() async {
    setState(() => _isLoading = true);
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
          _payerFilterOptions = [_allPayersOption, ...payerProvider.payers];
          _selectedPayerFilter = _allPayersOption;
        });
      }

      await _loadReportData();
    } catch (e) {
      developer.log('Error init report: $e', name: 'ReportScreen', error: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReportData() async {
    if (!mounted) return;

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);

    final filteredExpenses = expenseProvider.expenses.where((exp) {
      final matchYear = exp.date.year == _selectedYear;
      final matchMonth = _range == ReportRange.year ||
          (_selectedMonth != null && exp.date.month == _selectedMonth);
      final matchPayer = _selectedPayerFilter == null ||
          _selectedPayerFilter!.id == -1 ||
          exp.payerId == _selectedPayerFilter!.id;
      return matchYear && matchMonth && matchPayer;
    }).toList();

    // Category totals
    final tempCategoryTotals = <int, double>{};
    for (final exp in filteredExpenses) {
      final cid = exp.categoryId ?? -1;
      tempCategoryTotals.update(cid, (v) => v + exp.amount, ifAbsent: () => exp.amount);
    }

    // Bar groups
    final tempBarGroups = <BarChartGroupData>[];
    double tempMaxY = 0;

    if (_range == ReportRange.year) {
      final monthly = <int, double>{for (var m = 1; m <= 12; m++) m: 0.0};
      for (final exp in filteredExpenses) {
        monthly[exp.date.month] = (monthly[exp.date.month] ?? 0) + exp.amount;
      }
      for (int m = 1; m <= 12; m++) {
        final val = monthly[m] ?? 0;
        if (val > tempMaxY) tempMaxY = val;
        tempBarGroups.add(
          BarChartGroupData(
            x: m,
            barRods: [
              BarChartRodData(
                toY: val,
                color: Theme.of(context).primaryColor,
                width: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }
    } else {
      final month = _selectedMonth ?? DateTime.now().month;
      final daysInMonth = DateTime(_selectedYear, month + 1, 0).day;
      if (_monthGranularity == MonthGranularity.weekly) {
        final weekTotals = <int, double>{};
        int weekIndex(int day) => ((day - 1) / 7).floor() + 1;
        for (final exp in filteredExpenses) {
          final w = weekIndex(exp.date.day);
          weekTotals.update(w, (v) => v + exp.amount, ifAbsent: () => exp.amount);
        }
        final totalWeeks = weekIndex(daysInMonth);
        for (int w = 1; w <= totalWeeks; w++) {
          final val = weekTotals[w] ?? 0;
          if (val > tempMaxY) tempMaxY = val;
          tempBarGroups.add(
            BarChartGroupData(
              x: w,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: Theme.of(context).primaryColor,
                  width: 24,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          );
        }
      } else {
        // daily
        final dailyTotals = <int, double>{for (var d = 1; d <= daysInMonth; d++) d: 0.0};
        for (final exp in filteredExpenses) {
          dailyTotals[exp.date.day] = (dailyTotals[exp.date.day] ?? 0) + exp.amount;
        }
        for (int d = 1; d <= daysInMonth; d++) {
          final val = dailyTotals[d] ?? 0;
          if (val > tempMaxY) tempMaxY = val;
          tempBarGroups.add(
            BarChartGroupData(
              x: d,
              barRods: [
                BarChartRodData(
                  toY: val,
                  color: Theme.of(context).primaryColor,
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }
      }
    }

    tempMaxY = (tempMaxY * 1.2).ceilToDouble();
    if (tempMaxY < 100) tempMaxY = 100;

    // Pie chart
    final tempPieSections = <PieChartSectionData>[];
    final total = filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    if (tempCategoryTotals.isEmpty || total == 0) {
      tempPieSections.add(
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          title: 'No Data',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    } else {
      tempCategoryTotals.entries.where((e) => e.value > 0).forEach((entry) {
        final category = categoryProvider.categories.firstWhere(
          (c) => c.id == entry.key,
          orElse: () => Category(
            id: -1,
            name: 'Unknown Category',
            color: 0xFF9E9E9E,
          ),
        );
        final pct = (entry.value / total) * 100;
        final sectionColor = (category.color == null || category.color == 0)
            ? _getCategoryColor(category.id!)
            : Color(category.color!);
        tempPieSections.add(
          PieChartSectionData(
            color: sectionColor,
            value: entry.value,
            title: '${category.name}\n${pct.toStringAsFixed(1)}%',
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: category.id == -1
                ? const Icon(Icons.help_outline, color: Colors.white, size: 18)
                : null,
          ),
        );
      });
    }

    if (!mounted) return;
    setState(() {
      _categoryTotals = tempCategoryTotals;
      _barGroups = tempBarGroups;
      _maxYValue = tempMaxY;
      _pieChartSections = tempPieSections;
      _totalPeriodExpenses = total;
    });
  }

  // ----- Titles -----
  String _periodTitleTotal() {
    if (_range == ReportRange.year) return 'Total Expenses in $_selectedYear';
    final m = DateFormat.MMMM().format(DateTime(_selectedYear, _selectedMonth!));
    return 'Total Expenses in $m $_selectedYear';
  }

  String _barChartTitle() {
    if (_range == ReportRange.year) return 'Monthly Expenses in $_selectedYear';
    final m = DateFormat.MMMM().format(DateTime(_selectedYear, _selectedMonth!));
    return _monthGranularity == MonthGranularity.weekly
        ? 'Weekly Expenses in $m $_selectedYear'
        : 'Daily Expenses in $m $_selectedYear';
  }

  String _pieChartTitle() {
    if (_range == ReportRange.year) return 'Category Breakdown (Year)';
    final m = DateFormat.MMMM().format(DateTime(_selectedYear, _selectedMonth!));
    return 'Category Breakdown ($m)';
  }

  // ----- UI builders -----
  Widget _buildRangeSelector() {
    return SegmentedButton<ReportRange>(
      segments: const [
        ButtonSegment(value: ReportRange.year, icon: Icon(Icons.calendar_view_month), label: Text('ปี')),
        ButtonSegment(value: ReportRange.month, icon: Icon(Icons.calendar_view_day), label: Text('เดือน')),
      ],
      selected: {_range},
      onSelectionChanged: (set) {
        final val = set.first;
        if (val != _range) {
          setState(() {
            _range = val;
            if (_range == ReportRange.year) {
              _selectedMonth = null;
            } else {
              _selectedMonth ??= DateTime.now().month;
            }
          });
          _loadReportData();
        }
      },
    );
  }

  Widget _buildMonthGranularitySelector() {
    if (_range != ReportRange.month) return const SizedBox.shrink();
    return SegmentedButton<MonthGranularity>(
      segments: const [
        ButtonSegment(value: MonthGranularity.weekly, icon: Icon(Icons.view_week), label: Text('รายสัปดาห์')),
        ButtonSegment(value: MonthGranularity.daily, icon: Icon(Icons.calendar_today), label: Text('รายวัน')),
      ],
      selected: {_monthGranularity},
      onSelectionChanged: (set) {
        final val = set.first;
        if (val != _monthGranularity) {
          setState(() => _monthGranularity = val);
          _loadReportData();
        }
      },
    );
  }

  SideTitles _buildBottomTitles() {
    final isDailyMode = _range == ReportRange.month && _monthGranularity == MonthGranularity.daily;
    final isWeekly = _range == ReportRange.month && _monthGranularity == MonthGranularity.weekly;
    final isYear = _range == ReportRange.year;

    double reserved;
    if (isYear) {
      reserved = 24;
    } else if (isWeekly) {
      reserved = 30;
    } else {
      reserved = 48;
    }

    return SideTitles(
      showTitles: true,
      reservedSize: reserved,
      getTitlesWidget: (value, meta) {
        String label = '';
        if (isYear) {
          label = DateFormat.MMM().format(DateTime(2023, value.toInt()));
        } else if (isWeekly) {
          label = 'W${value.toInt()}';
        } else if (isDailyMode) {
          final day = value.toInt();
          final lastDay = _selectedMonth == null
              ? 31
              : DateTime(_selectedYear, _selectedMonth! + 1, 0).day;
          if ([1, 5, 10, 15, 20, 25, lastDay].contains(day)) {
            label = day.toString();
          }
        }

        if (label.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10),
          ),
        );
      },
    );
  }

  Widget _buildBarChartWrapper() {
    final isDailyMode = _range == ReportRange.month && _monthGranularity == MonthGranularity.daily;
    double contentWidth = MediaQuery.of(context).size.width - 48;
    if (isDailyMode && _selectedMonth != null) {
      final days = DateTime(_selectedYear, _selectedMonth! + 1, 0).day;
      contentWidth = (days * 26).toDouble().clamp(
        MediaQuery.of(context).size.width - 48,
        double.infinity,
      );
    }

    final chart = BarChart(
      BarChartData(
        barGroups: _barGroups,
        maxY: _maxYValue,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _maxYValue <= 10 ? 2 : null,
          getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.shade300, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: _buildBottomTitles()),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (val, meta) => Text(
                val.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String head;
              if (_range == ReportRange.year) {
                head = DateFormat.MMM().format(DateTime(2023, group.x));
              } else if (_monthGranularity == MonthGranularity.weekly) {
                head = 'Week ${group.x}';
              } else {
                head = 'Day ${group.x}';
              }
              return BarTooltipItem(
                '$head\n${rod.toY.toStringAsFixed(2)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
      ),
      // swapAnimationDuration deprecated: replaced with duration
      duration: const Duration(milliseconds: 250),
    );

    if (isDailyMode) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: contentWidth, child: chart),
      );
    }
    return chart;
  }

  // ----- Build -----
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense Report')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Report')),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRangeSelector(),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Select Year',
                  border: OutlineInputBorder(),
                ),
                items: _availableYears
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedYear = val);
                    _loadReportData();
                  }
                },
              ),
              if (_range == ReportRange.month) const SizedBox(height: 16),
              if (_range == ReportRange.month)
                DropdownButtonFormField<int>(
                  value: _selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Select Month',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(DateFormat.MMMM().format(DateTime(2000, i + 1))),
                    ),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMonth = val);
                      _loadReportData();
                    }
                  },
                ),
              if (_range == ReportRange.month) const SizedBox(height: 16),
              _buildMonthGranularitySelector(),
              if (_range == ReportRange.month) const SizedBox(height: 16),
              DropdownButtonFormField<Payer>(
                value: _selectedPayerFilter,
                decoration: const InputDecoration(
                  labelText: 'Filter by Payer',
                  border: OutlineInputBorder(),
                ),
                items: _payerFilterOptions
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name),
                      ),
                    )
                    .toList(),
                onChanged: (p) {
                  if (p != null) {
                    setState(() => _selectedPayerFilter = p);
                    _loadReportData();
                  }
                },
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_periodTitleTotal()}:',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${_totalPeriodExpenses.toStringAsFixed(2)} ฿',
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
              const SizedBox(height: 12),
              Text(
                _barChartTitle(),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: _range == ReportRange.month &&
                        _monthGranularity == MonthGranularity.daily
                    ? 300
                    : 260,
                child: Card(
                  elevation: 4,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    child: _buildBarChartWrapper(),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                _pieChartTitle(),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 250,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: PieChart(
                      PieChartData(
                        sections: _pieChartSections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (event.isInterestedForInteractions) {
                              setState(() {});
                            }
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
                  (c) => c.id == entry.key,
                  orElse: () => Category(
                    id: -1,
                    name: 'Unknown Category',
                    color: 0xFF9E9E9E,
                  ),
                );
                final legendColor = (category.color == null || category.color == 0)
                    ? _getCategoryColor(category.id!)
                    : Color(category.color!);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: Row(
                    children: [
                      Container(width: 16, height: 16, color: legendColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${category.name}: ${entry.value.toStringAsFixed(2)} ฿',
                          overflow: TextOverflow.ellipsis,
                        ),
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