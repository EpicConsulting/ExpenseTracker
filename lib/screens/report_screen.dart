import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer; // สำหรับ logging

import '../models/expense.dart';
import '../models/category.dart';
import '../models/payer.dart'; // เพิ่ม import สำหรับ Payer model
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../providers/payer_provider.dart'; // เพิ่ม import สำหรับ PayerProvider
import '../widgets/app_drawer.dart';

class ReportScreen extends StatefulWidget {
  static const routeName = '/report';

  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // ปีที่เลือกสำหรับรายงาน
  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = []; // รายการปีที่มีข้อมูลจาก DB

  // ตัวแปรสำหรับ Payer Filter
  Payer _allPayersOption = Payer(id: -1, name: 'All Payers'); // Payer พิเศษสำหรับ "ทั้งหมด"
  List<Payer> _payerFilterOptions = []; // รายการผู้จ่ายสำหรับ Dropdown
  Payer? _selectedPayerFilter; // ผู้จ่ายที่เลือกสำหรับกรอง

  bool _isLoading = true; // สถานะการโหลดข้อมูลเริ่มต้น

  // ข้อมูลสำหรับกราฟและยอดรวม
  Map<int, double> _monthlyTotals = {};
  Map<int, double> _categoryTotals = {};
  List<BarChartGroupData> _barGroups = [];
  List<PieChartSectionData> _pieChartSections = [];
  double _maxYValue = 0;
  double _totalAnnualExpenses = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialDataAndReport(); // โหลดข้อมูลเริ่มต้นและคำนวณรายงาน
  }

  // เมธอดสำหรับโหลดข้อมูลเริ่มต้น (ปี, ผู้จ่าย) และคำนวณรายงาน
  Future<void> _loadInitialDataAndReport() async {
    developer.log('Loading initial data for ReportScreen...', name: 'ReportScreen');
    setState(() {
      _isLoading = true;
    });

    try {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final payerProvider = Provider.of<PayerProvider>(context, listen: false);
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false); // GET CategoryProvider INSTANCE

      // ENSURE CATEGORIES ARE FETCHED BEFORE PROCEEDING TO BUILD REPORT DATA
      await categoryProvider.fetchCategories(); // ADDED: EXPLICITLY FETCH CATEGORIES

      // โหลดปีที่มีข้อมูล
      final years = await expenseProvider.getAvailableExpenseYears();
      if (mounted) {
        setState(() {
          _availableYears = years.isNotEmpty ? years : [DateTime.now().year]; // ถ้าไม่มีปี ให้ใช้ปีปัจจุบัน
          // ตรวจสอบว่า _selectedYear ยังอยู่ใน _availableYears หรือไม่
          if (!_availableYears.contains(_selectedYear)) {
            _selectedYear = _availableYears.first; // ตั้งค่าปีเริ่มต้นเป็นปีล่าสุดที่มีข้อมูล
          }
        });
      }

      // โหลดผู้จ่ายและเตรียมตัวเลือก filter
      await payerProvider.fetchPayers(); // ให้แน่ใจว่าโหลด Payers แล้ว
      if (mounted) {
        setState(() {
          _payerFilterOptions = [
            _allPayersOption, // เพิ่มตัวเลือก "ทั้งหมด"
            ...payerProvider.payers, // เพิ่ม Payers จริง
          ];
          _selectedPayerFilter = _allPayersOption; // ตั้งค่าเริ่มต้นเป็น "ทั้งหมด"
        });
      }

      // โหลดและคำนวณข้อมูลรายงานครั้งแรก
      await _loadReportData();

    } catch (e) {
      developer.log('Error loading initial report data: $e', name: 'ReportScreen', error: e);
      // อาจแสดงข้อความ Error บน UI
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // เมธอดสำหรับโหลดและคำนวณข้อมูลรายงานตามปีและผู้จ่ายที่เลือก
  Future<void> _loadReportData() async {
    developer.log('Loading report data for year: $_selectedYear, payer: ${_selectedPayerFilter?.name}', name: 'ReportScreen');

    if (!mounted) {
      developer.log('ReportScreen is not mounted during _loadReportData call.', name: 'ReportScreen');
      return;
    }

    // ใช้ listen: false เพื่อไม่ให้ build ใหม่เมื่อ Provider เปลี่ยนแปลง แต่จะเรียกเมธอดตรงๆ
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);

    // กรองค่าใช้จ่ายตามปีและผู้จ่ายที่เลือก
    List<Expense> filteredExpenses;
    if (_selectedPayerFilter != null && _selectedPayerFilter!.id != -1) {
      filteredExpenses = expenseProvider.expenses
          .where((exp) =>
      exp.date.year == _selectedYear &&
          exp.payerId == _selectedPayerFilter!.id)
          .toList();
    } else {
      // ไม่มีการกรองผู้จ่าย หรือเลือก "All Payers"
      filteredExpenses = expenseProvider.expenses
          .where((exp) => exp.date.year == _selectedYear)
          .toList();
    }

    // คำนวณยอดรวมค่าใช้จ่ายต่อเดือน
    Map<int, double> tempMonthlyTotals = {};
    for (int i = 1; i <= 12; i++) {
      tempMonthlyTotals[i] = 0.0;
    }
    for (var exp in filteredExpenses) {
      tempMonthlyTotals[exp.date.month] =
          (tempMonthlyTotals[exp.date.month] ?? 0.0) + exp.amount;
    }

    // คำนวณยอดรวมค่าใช้จ่ายต่อหมวดหมู่
    Map<int, double> tempCategoryTotals = {};
    for (var exp in filteredExpenses) {
      final int categoryId = exp.categoryId ?? -1;
      tempCategoryTotals.update(
        categoryId,
            (value) => value + exp.amount,
        ifAbsent: () => exp.amount,
      );
    }

    // เตรียมข้อมูลสำหรับ Bar Chart
    List<BarChartGroupData> tempBarGroups = [];
    double tempMaxYValue = 0;

    for (int i = 1; i <= 12; i++) {
      final amount = tempMonthlyTotals[i] ?? 0.0;
      if (amount > tempMaxYValue) {
        tempMaxYValue = amount;
      }
      tempBarGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: amount,
              color: Theme.of(context).primaryColor,
              width: 15,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    tempMaxYValue = (tempMaxYValue * 1.2).ceilToDouble();
    if (tempMaxYValue < 100) tempMaxYValue = 100; // กำหนดขั้นต่ำเพื่อไม่ให้กราฟแบนราบเกินไป

    // เตรียมข้อมูลสำหรับ Pie Chart
    List<PieChartSectionData> tempPieChartSections = [];
    double tempTotalAnnualExpenses = filteredExpenses.map((e) => e.amount).fold(0.0, (sum, item) => sum + item);

    if (tempCategoryTotals.isEmpty || tempTotalAnnualExpenses == 0) {
      tempPieChartSections.add(
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          title: 'No Data',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    } else {
      tempCategoryTotals.entries.where((entry) => entry.value > 0).forEach((entry) {
        final category = categoryProvider.categories.firstWhere(
              (cat) => cat.id == entry.key,
          orElse: () => Category(id: -1, name: 'Unknown Category', color: Colors.grey.value), // Category constructor now accepts color
        );
        final double percentage = (entry.value / tempTotalAnnualExpenses) * 100;

        Color sectionColor = Colors.grey; // Default color
        if (category.color != null) {
          sectionColor = Color(category.color!);
        } else {
          sectionColor = _getCategoryColor(category.id!);
        }


        tempPieChartSections.add(
          PieChartSectionData(
            color: sectionColor,
            value: entry.value,
            title: '${category.name}\n${percentage.toStringAsFixed(1)}%',
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: category.id == -1 ? const Icon(Icons.help_outline, color: Colors.white, size: 18) : null,
          ),
        );
      });
    }


    if (mounted) {
      setState(() {
        _monthlyTotals = tempMonthlyTotals;
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
      return Scaffold( // REMOVED `const`
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dropdown สำหรับเลือกปี
                DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Select Year',
                    border: OutlineInputBorder(),
                  ),
                  items: _availableYears
                      .map((year) => DropdownMenuItem(
                    value: year,
                    child: Text('$year'),
                  ))
                      .toList(),
                  onChanged: (year) {
                    if (year != null) {
                      setState(() {
                        _selectedYear = year;
                      });
                      _loadReportData(); // โหลดข้อมูลรายงานใหม่เมื่อเลือกปี
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Dropdown สำหรับเลือกผู้จ่าย
                DropdownButtonFormField<Payer>(
                  value: _selectedPayerFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Payer',
                    border: OutlineInputBorder(),
                  ),
                  items: _payerFilterOptions
                      .map((payer) => DropdownMenuItem(
                    value: payer,
                    child: Text(payer.name),
                  ))
                      .toList(),
                  onChanged: (Payer? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedPayerFilter = newValue;
                      });
                      _loadReportData(); // โหลดข้อมูลรายงานใหม่เมื่อเลือก Payer
                    }
                  },
                ),
                const SizedBox(height: 20),

                // ยอดรวมค่าใช้จ่ายสำหรับปีที่เลือก
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded( // ADDED: Wrap Text in Expanded
                          child: Text(
                            'Total Expenses in $_selectedYear:',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Expanded( // ADDED: Wrap Text in Expanded
                          child: Text(
                            '${_totalAnnualExpenses.toStringAsFixed(2)} ฿', // แสดงยอดรวม
                            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.right, // Optional: align amount to the right
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bar Chart: ค่าใช้จ่ายรายเดือน
                Text(
                  'Monthly Expenses in $_selectedYear',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 250, // กำหนดความสูงของกราฟ
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
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final String monthName = DateFormat.MMM().format(DateTime(2023, value.toInt()));
                                  return SideTitleWidget(
                                    meta: meta, // ADDED: meta parameter is required
                                    space: 4.0,
                                    child: Text(
                                      monthName,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                },
                                reservedSize: 20,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return SideTitleWidget(
                                    meta: meta, // ADDED: meta parameter is required
                                    space: 4.0,
                                    child: Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black,
                                      ),
                                    ),
                                  );
                                },
                                reservedSize: 40,
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

                // Pie Chart: สัดส่วนค่าใช้จ่ายต่อหมวดหมู่
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
                          sections: _pieChartSections, // ใช้ _pieChartSections ที่คำนวณแล้ว
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              // โค้ดสำหรับ interactive (ถ้าต้องการ)
                            });
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Legend (สำหรับ Pie Chart)
                Text(
                  'Category Legend',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // แสดง Legend ตาม _categoryTotals ที่คำนวณมา
                ..._categoryTotals.entries.where((entry) => entry.value > 0).map((entry) {
                  final category = Provider.of<CategoryProvider>(context).categories.firstWhere(
                        (cat) => cat.id == entry.key,
                    orElse: () => Category(id: -1, name: 'Unknown Category', color: Colors.grey.value),
                  );
                  Color legendColor = Colors.grey;
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
                        Expanded( // ADDED: Wrap Text in Expanded to prevent overflow
                          child: Text('${category.name}: ${entry.value.toStringAsFixed(2)} ฿'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ฟังก์ชันสำหรับกำหนดสีของหมวดหมู่ (ตัวอย่าง)
  // ใช้เมื่อ Category object ไม่มีสี (null) หรือสำหรับ "Unknown Category"
  Color _getCategoryColor(int categoryId) {
    switch (categoryId % 5) {
      case 0: return Colors.blue.shade700;
      case 1: return Colors.green.shade700;
      case 2: return Colors.orange.shade700;
      case 3: return Colors.purple.shade700;
      case 4: return Colors.red.shade700;
      default: return Colors.grey; // สำหรับ categoryId -1 (Unknown Category)
    }
  }
}