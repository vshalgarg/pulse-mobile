import 'package:flutter/material.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/constants_methods.dart';

class DGChecklistSection extends StatefulWidget {
  final VoidCallback onFormChanged;

  const DGChecklistSection({
    super.key,
    required this.onFormChanged,
  });

  @override
  State<DGChecklistSection> createState() => _DGChecklistSectionState();
}

class _DGChecklistSectionState extends State<DGChecklistSection> {
  bool _isExpanded = false;
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _phaseController = TextEditingController();

  String? _canopyCleanliness;
  String? _amfFunctioning;
  String? _earthingConnection;
  String? _loadBalancing;
  String? _exhaustFan;
  String? _batteryGravity;
  String? _chargingAlternator;
  String? _wiringHarness;
  String? _fuelPipe;
  String? _fuelTank;
  String? _batteryTerminal;
  String? _fuelLevel;
  String? _fuelFilter;
  String? _fuelLeakage;
  String? _radiatorPressureCap;
  String? _radiatorFin;
  String? _radiatorHose;
  String? _coolantLevel;
  String? _coolantLeakage;
  String? _fanBelt;
  String? _lubeOilLevel;
  String? _oilLeakage;
  String? _lubeOilFilter;
  String? _airCleaner;
  String? _hose;
  String? _hoseClamp;

  @override
  void initState() {
    super.initState();
    _makeController.text = "Eicher";
    _ratingController.text = "1500 KW";
    _phaseController.text = "3";
  }

  @override
  void dispose() {
    _makeController.dispose();
    _ratingController.dispose();
    _phaseController.dispose();
    super.dispose();
  }

  void _onFormChanged() => widget.onFormChanged();

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accordion Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C), // Dark teal background
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "DG",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  onPressed: _toggleExpansion,
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Accordion Content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Rating, Phase, Make
                  CustomFormField(
                    label: "Rating",
                    controller: _ratingController,
                    isRequired: true,
                    onChanged: (_) => _onFormChanged(),
                  ),
                  getHeight(15),
                  CustomFormField(
                    label: "Phase (in case of DG)",
                    controller: _phaseController,
                    isRequired: true,
                    onChanged: (_) => _onFormChanged(),
                  ),
                  getHeight(15),
                  CustomFormField(
                    label: "Make",
                    controller: _makeController,
                    isRequired: true,
                    onChanged: (_) => _onFormChanged(),
                  ),
                  getHeight(20),

                  // DG Canopy Cleanliness
                  _buildChecklistItem("DG Canopy cleanliness", _canopyCleanliness, (v) {
                    setState(() {
                      _canopyCleanliness = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // AMF Functioning
                  _buildAMFChecklistItem("AMF Functioning", _amfFunctioning, (v) {
                    setState(() {
                      _amfFunctioning = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Earthing Connection
                  _buildChecklistItem("Earthing Connection", _earthingConnection, (v) {
                    setState(() {
                      _earthingConnection = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Load Balancing
                  _buildChecklistItem("Load Balancing in all 3 phases", _loadBalancing, (v) {
                    setState(() {
                      _loadBalancing = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Exhaust Fan
                  _buildChecklistItem("Exhaust Fan", _exhaustFan, (v) {
                    setState(() {
                      _exhaustFan = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // DG Battery Gravity
                  _buildChecklistItem("DG Battery gravity", _batteryGravity, (v) {
                    setState(() {
                      _batteryGravity = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Charging Alternator
                  _buildChecklistItem("Charging Alternator", _chargingAlternator, (v) {
                    setState(() {
                      _chargingAlternator = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Wiring Harness Condition
                  _buildChecklistItem("Wiring Harness Condition", _wiringHarness, (v) {
                    setState(() {
                      _wiringHarness = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Fuel Pipe
                  _buildChecklistItem("Fuel Pipe", _fuelPipe, (v) {
                    setState(() {
                      _fuelPipe = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Fuel Tank
                  _buildChecklistItem("Fuel Tank", _fuelTank, (v) {
                    setState(() {
                      _fuelTank = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // DG Battery Terminal
                  _buildChecklistItem("DG Battery Terminal", _batteryTerminal, (v) {
                    setState(() {
                      _batteryTerminal = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Fuel Level
                  _buildChecklistItem("Fuel Level", _fuelLevel, (v) {
                    setState(() {
                      _fuelLevel = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Fuel Filter
                  _buildChecklistItem("Fuel filter", _fuelFilter, (v) {
                    setState(() {
                      _fuelFilter = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Fuel Leakage
                  _buildChecklistItem("Fuel Leakage", _fuelLeakage, (v) {
                    setState(() {
                      _fuelLeakage = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Radiator pressure cap
                  _buildChecklistItem("Radiator pressure cap", _radiatorPressureCap, (v) {
                    setState(() {
                      _radiatorPressureCap = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Radiator fin
                  _buildChecklistItem("Radiator fin", _radiatorFin, (v) {
                    setState(() {
                      _radiatorFin = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Radiator Hose
                  _buildChecklistItem("Radiator Hose", _radiatorHose, (v) {
                    setState(() {
                      _radiatorHose = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Coolant level
                  _buildChecklistItem("Coolant level", _coolantLevel, (v) {
                    setState(() {
                      _coolantLevel = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Coolant leakage
                  _buildChecklistItem("Coolant leakage", _coolantLeakage, (v) {
                    setState(() {
                      _coolantLeakage = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Fan Belt
                  _buildChecklistItem("Fan Belt", _fanBelt, (v) {
                    setState(() {
                      _fanBelt = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Lube Oil Level
                  _buildChecklistItem("Lube Oil Level", _lubeOilLevel, (v) {
                    setState(() {
                      _lubeOilLevel = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Oil leakage
                  _buildChecklistItem("Oil leakage", _oilLeakage, (v) {
                    setState(() {
                      _oilLeakage = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Lube Oil filter
                  _buildChecklistItem("Lube Oil filter", _lubeOilFilter, (v) {
                    setState(() {
                      _lubeOilFilter = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Air Cleaner
                  _buildChecklistItem("Air Cleaner", _airCleaner, (v) {
                    setState(() {
                      _airCleaner = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Hose
                  _buildChecklistItem("Hose", _hose, (v) {
                    setState(() {
                      _hose = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),

                  // Hose Clamp
                  _buildChecklistItem("Hose Clamp", _hoseClamp, (v) {
                    setState(() {
                      _hoseClamp = v;
                      _onFormChanged();
                    });
                  }),
                  getHeight(15),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String label, String? selectedValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label.replaceAll(' *', ''), // Remove the asterisk from the label text
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
              ),
              const TextSpan(
                text: " *",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Radio<String>(
              value: 'Ok',
              groupValue: selectedValue,
              onChanged: onChanged,
              activeColor: Colors.white,
              fillColor: MaterialStateProperty.all(Colors.white),
            ),
            const Text('Ok', style: TextStyle(color: Colors.white)),
            const SizedBox(width: 20),
            Radio<String>(
              value: 'Not Ok',
              groupValue: selectedValue,
              onChanged: onChanged,
              activeColor: Colors.white,
              fillColor: MaterialStateProperty.all(Colors.white),
            ),
            const Text('Not Ok', style: TextStyle(color: Colors.white)),
          ],
        ),
      ],
    );
  }

  Widget _buildAMFChecklistItem(String label, String? selectedValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label.replaceAll(' *', ''), // Remove the asterisk from the label text
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
              ),
              const TextSpan(
                text: " *",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Radio<String>(
              value: 'Auto',
              groupValue: selectedValue,
              onChanged: onChanged,
              activeColor: Colors.white,
              fillColor: MaterialStateProperty.all(Colors.white),
            ),
            const Text('Auto', style: TextStyle(color: Colors.white)),
            const SizedBox(width: 20),
            Radio<String>(
              value: 'Manual',
              groupValue: selectedValue,
              onChanged: onChanged,
              activeColor: Colors.white,
              fillColor: MaterialStateProperty.all(Colors.white),
            ),
            const Text('Manual', style: TextStyle(color: Colors.white)),
          ],
        ),
      ],
    );
  }

  Map<String, dynamic> getChecklistData() {
    return {
      'rating': _ratingController.text,
      'phase': _phaseController.text,
      'make': _makeController.text,
      'canopyCleanliness': _canopyCleanliness,
      'amfFunctioning': _amfFunctioning,
      'earthingConnection': _earthingConnection,
      'loadBalancing': _loadBalancing,
      'exhaustFan': _exhaustFan,
      'batteryGravity': _batteryGravity,
      'chargingAlternator': _chargingAlternator,
      'wiringHarness': _wiringHarness,
      'fuelPipe': _fuelPipe,
      'fuelTank': _fuelTank,
      'batteryTerminal': _batteryTerminal,
      'fuelLevel': _fuelLevel,
      'fuelFilter': _fuelFilter,
      'fuelLeakage': _fuelLeakage,
      'radiatorPressureCap': _radiatorPressureCap,
      'radiatorFin': _radiatorFin,
      'radiatorHose': _radiatorHose,
      'coolantLevel': _coolantLevel,
      'coolantLeakage': _coolantLeakage,
      'fanBelt': _fanBelt,
      'lubeOilLevel': _lubeOilLevel,
      'oilLeakage': _oilLeakage,
      'lubeOilFilter': _lubeOilFilter,
      'airCleaner': _airCleaner,
      'hose': _hose,
      'hoseClamp': _hoseClamp,
    };
  }

  bool validateDGChecklist() {
    return _ratingController.text.isNotEmpty &&
        _phaseController.text.isNotEmpty &&
        _makeController.text.isNotEmpty;
  }
}