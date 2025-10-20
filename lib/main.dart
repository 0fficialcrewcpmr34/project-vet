import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const VetToolApp());
}

class VetToolApp extends StatelessWidget {
  const VetToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vet Tool by Crew',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const MedicationCalculatorPage(),
    );
  }
}

enum Species { dog, cat }

enum WeightUnit { kg, lb }

class MedicationCalculatorPage extends StatefulWidget {
  const MedicationCalculatorPage({super.key});

  @override
  State<MedicationCalculatorPage> createState() => _MedicationCalculatorPageState();
}

class _MedicationCalculatorPageState extends State<MedicationCalculatorPage> {
  late Future<List<Medication>> _medicationsFuture;
  Species _selectedSpecies = Species.dog;
  WeightUnit _weightUnit = WeightUnit.kg;
  Medication? _selectedMedication;
  RouteGuideline? _selectedRoute;
  final TextEditingController _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _medicationsFuture = _loadMedications();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<List<Medication>> _loadMedications() async {
    final jsonString = await rootBundle.loadString('assets/medications.json');
    final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
    return decoded
        .map((e) => Medication.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vet Tool by Crew'),
      ),
      body: FutureBuilder<List<Medication>>(
        future: _medicationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load medications data.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final medications = snapshot.data ?? [];
          final filtered = medications
              .where((med) => med.species.contains(_selectedSpecies))
              .toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Text('No medications available for the selected species.'),
            );
          }

          _selectedMedication = filtered.contains(_selectedMedication)
              ? _selectedMedication
              : filtered.first;
          _selectedRoute = _selectedMedication!.routes.contains(_selectedRoute)
              ? _selectedRoute
              : _selectedMedication!.routes.first;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final content = _buildContent(filtered);
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 600 : double.infinity),
                    child: content,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(List<Medication> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick dosage calculator',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildSpeciesSelector(),
        const SizedBox(height: 16),
        _buildMedicationSelector(filtered),
        const SizedBox(height: 16),
        _buildRouteSelector(),
        const SizedBox(height: 16),
        _buildWeightInput(),
        const SizedBox(height: 24),
        _buildDosageCard(),
        const SizedBox(height: 24),
        _buildNotesCard(),
      ],
    );
  }

  Widget _buildSpeciesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Species', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<Species>(
          segments: const [
            ButtonSegment(value: Species.dog, label: Text('Dog'), icon: Icon(Icons.pets)),
            ButtonSegment(value: Species.cat, label: Text('Cat'), icon: Icon(Icons.pets_outlined)),
          ],
          selected: <Species>{_selectedSpecies},
          onSelectionChanged: (value) {
            setState(() {
              _selectedSpecies = value.first;
              _selectedMedication = null;
              _selectedRoute = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildMedicationSelector(List<Medication> medications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Medication', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<Medication>(
          value: _selectedMedication,
          items: medications
              .map(
                (med) => DropdownMenuItem(
                  value: med,
                  child: Text(med.name),
                ),
              )
              .toList(),
          onChanged: (med) {
            setState(() {
              _selectedMedication = med;
              _selectedRoute = med?.routes.first;
            });
          },
          decoration: const InputDecoration(
            hintText: 'Select medication',
          ),
        ),
        if (_selectedMedication?.commonUse != null) ...[
          const SizedBox(height: 8),
          Text(
            _selectedMedication!.commonUse!,
            style: const TextStyle(color: Colors.black54),
          ),
        ]
      ],
    );
  }

  Widget _buildRouteSelector() {
    final routes = _selectedMedication?.routes ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Route', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<RouteGuideline>(
          value: _selectedRoute,
          items: routes
              .map((route) => DropdownMenuItem(
                    value: route,
                    child: Text(route.name),
                  ))
              .toList(),
          onChanged: (route) {
            setState(() {
              _selectedRoute = route;
            });
          },
          decoration: const InputDecoration(hintText: 'Select route'),
        ),
        if (_selectedRoute?.frequency != null) ...[
          const SizedBox(height: 8),
          Text(
            'Frequency: ${_selectedRoute!.frequency}',
            style: const TextStyle(color: Colors.black54),
          ),
        ]
      ],
    );
  }

  Widget _buildWeightInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Patient weight', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter weight in ${_weightUnit == WeightUnit.kg ? 'kg' : 'lb'}',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear weight',
                    onPressed: () {
                      setState(() {
                        _weightController.clear();
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<WeightUnit>(
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
              ],
              selected: <WeightUnit>{_weightUnit},
              onSelectionChanged: (value) {
                if (_weightController.text.isEmpty) {
                  setState(() {
                    _weightUnit = value.first;
                  });
                  return;
                }
                final parsed = double.tryParse(_weightController.text);
                if (parsed == null) {
                  setState(() {
                    _weightController.clear();
                    _weightUnit = value.first;
                  });
                  return;
                }
                setState(() {
                  if (_weightUnit == WeightUnit.kg && value.first == WeightUnit.lb) {
                    _weightController.text = (parsed * 2.2046226218).toStringAsFixed(2);
                  } else if (_weightUnit == WeightUnit.lb && value.first == WeightUnit.kg) {
                    _weightController.text = (parsed * 0.45359237).toStringAsFixed(2);
                  }
                  _weightUnit = value.first;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDosageCard() {
    final route = _selectedRoute;
    final weightInput = double.tryParse(_weightController.text.replaceAll(',', '.'));
    final weightKg = weightInput == null
        ? null
        : (_weightUnit == WeightUnit.kg ? weightInput : weightInput * 0.45359237);

    double? doseMg;
    double? minDoseMg;
    double? maxDoseMg;

    if (route != null && weightKg != null) {
      doseMg = route.dosage.perKg != null ? route.dosage.perKg! * weightKg : null;
      minDoseMg = route.dosage.minPerKg != null ? route.dosage.minPerKg! * weightKg : null;
      maxDoseMg = route.dosage.maxPerKg != null ? route.dosage.maxPerKg! * weightKg : null;
      if (doseMg == null && minDoseMg != null && maxDoseMg != null) {
        doseMg = ((minDoseMg + maxDoseMg) / 2).toDouble();
      }
      if (route.maxTotalDoseMg != null) {
        if (doseMg != null) {
          doseMg = (doseMg!).clamp(0, route.maxTotalDoseMg!) as double;
        }
        if (maxDoseMg != null) {
          maxDoseMg = (maxDoseMg!).clamp(0, route.maxTotalDoseMg!) as double;
        }
        if (minDoseMg != null) {
          minDoseMg = (minDoseMg!).clamp(0, route.maxTotalDoseMg!) as double;
        }
      }
    }

    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calculated dose',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (weightKg == null)
              const Text('Enter a valid weight to calculate dosing.')
            else if (route == null)
              const Text('Select a medication and route to view the dose.')
            else ...[
              if (doseMg != null)
                Text(
                  'Target dose: ${doseMg.toStringAsFixed(1)} mg',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              if (minDoseMg != null || maxDoseMg != null)
                Text(
                  'Range: '
                  '${minDoseMg != null ? minDoseMg.toStringAsFixed(1) : '—'} - '
                  '${maxDoseMg != null ? maxDoseMg.toStringAsFixed(1) : '—'} mg',
                ),
              Text(
                'Guideline: ${route.dosage.labelOrDefault}',
                style: const TextStyle(color: Colors.black54),
              ),
              if (route.maxTotalDoseMg != null)
                Text(
                  'Max total per dose: ${route.maxTotalDoseMg!.toStringAsFixed(1)} mg',
                  style: const TextStyle(color: Colors.black54),
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    final route = _selectedRoute;
    if (route == null) {
      return const SizedBox.shrink();
    }
    final notes = <String>[
      if (route.frequency != null) 'Give ${route.frequency!.toLowerCase()}.'
    ];
    if (route.notes != null && route.notes!.isNotEmpty) {
      notes.add(route.notes!);
    }
    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clinical guidance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(note),
              ),
          ],
        ),
      ),
    );
  }
}

class Medication {
  const Medication({
    required this.name,
    required this.species,
    required this.routes,
    this.commonUse,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      name: json['name'] as String,
      species: (json['species'] as List<dynamic>)
          .map((e) => (e as String).toSpecies())
          .whereType<Species>()
          .toList(),
      routes: (json['routes'] as List<dynamic>)
          .map((e) => RouteGuideline.fromJson(e as Map<String, dynamic>))
          .toList(),
      commonUse: json['commonUse'] as String?,
    );
  }

  final String name;
  final List<Species> species;
  final List<RouteGuideline> routes;
  final String? commonUse;
}

class RouteGuideline {
  const RouteGuideline({
    required this.name,
    required this.dosage,
    this.frequency,
    this.maxTotalDoseMg,
    this.notes,
  });

  factory RouteGuideline.fromJson(Map<String, dynamic> json) {
    return RouteGuideline(
      name: json['name'] as String,
      dosage: DosageGuideline.fromJson(json['dosage'] as Map<String, dynamic>),
      frequency: json['frequency'] as String?,
      maxTotalDoseMg: (json['maxTotalDoseMg'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  final String name;
  final DosageGuideline dosage;
  final String? frequency;
  final double? maxTotalDoseMg;
  final String? notes;
}

class DosageGuideline {
  const DosageGuideline({
    this.perKg,
    this.minPerKg,
    this.maxPerKg,
    required this.unit,
    this.label,
  });

  factory DosageGuideline.fromJson(Map<String, dynamic> json) {
    return DosageGuideline(
      perKg: (json['perKg'] as num?)?.toDouble(),
      minPerKg: (json['minPerKg'] as num?)?.toDouble(),
      maxPerKg: (json['maxPerKg'] as num?)?.toDouble(),
      unit: json['unit'] as String? ?? 'mg/kg',
      label: json['label'] as String?,
    );
  }

  final double? perKg;
  final double? minPerKg;
  final double? maxPerKg;
  final String unit;
  final String? label;

  String get labelOrDefault {
    final parts = <String>[];
    if (minPerKg != null || maxPerKg != null) {
      final minValue = minPerKg?.toStringAsFixed(1) ?? '—';
      final maxValue = maxPerKg?.toStringAsFixed(1) ?? '—';
      parts.add('$minValue-$maxValue $unit');
    } else if (perKg != null) {
      parts.add('${perKg!.toStringAsFixed(1)} $unit');
    }
    if (label != null && label!.isNotEmpty) {
      parts.add(label!);
    }
    if (parts.isEmpty) {
      parts.add(unit);
    }
    return parts.join(' · ');
  }
}

extension on String {
  Species? toSpecies() {
    switch (toLowerCase()) {
      case 'dog':
      case 'canine':
        return Species.dog;
      case 'cat':
      case 'feline':
        return Species.cat;
    }
    return null;
  }
}
