import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ordermate/features/settings/domain/models/pdf_settings.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';

class PdfSettingsScreen extends ConsumerStatefulWidget {
  const PdfSettingsScreen({super.key});

  @override
  ConsumerState<PdfSettingsScreen> createState() => _PdfSettingsScreenState();
}

class _PdfSettingsScreenState extends ConsumerState<PdfSettingsScreen> {
  late PdfSettings _localSettings;

  @override
  void initState() {
    super.initState();
    _localSettings = ref.read(settingsProvider).pdfSettings;
  }

  void _saveSettings() {
    ref.read(settingsProvider.notifier).setPdfSettings(_localSettings);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
    // User request: "just save immediately effects". We don't necessarily pop?
    // Usually settings screens stay open.
  }

  @override
  Widget build(BuildContext context) {
    // No watch, we control state locally until save

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print PDF Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Content Toggles'),
          SwitchListTile(
            title: const Text('Show Currency Symbol'),
            value: _localSettings.showCurrencySymbol,
            onChanged: (val) => setState(() => _localSettings =
                _localSettings.copyWith(showCurrencySymbol: val)),
          ),
          SwitchListTile(
            title: const Text('Show Decimals'),
            value: _localSettings.showDecimals,
            onChanged: (val) => setState(() =>
                _localSettings = _localSettings.copyWith(showDecimals: val)),
          ),
          SwitchListTile(
            title: const Text('Show Organization Name'),
            value: _localSettings.showOrgName,
            onChanged: (val) => setState(() =>
                _localSettings = _localSettings.copyWith(showOrgName: val)),
          ),
          SwitchListTile(
            title: const Text('Show Store Name'),
            value: _localSettings.showStoreName,
            onChanged: (val) => setState(() =>
                _localSettings = _localSettings.copyWith(showStoreName: val)),
          ),
          SwitchListTile(
            title: const Text('Show Address'),
            value: _localSettings.showAddress,
            onChanged: (val) => setState(() =>
                _localSettings = _localSettings.copyWith(showAddress: val)),
          ),
          SwitchListTile(
            title: const Text('Show Phone'),
            value: _localSettings.showPhone,
            onChanged: (val) => setState(
                () => _localSettings = _localSettings.copyWith(showPhone: val)),
          ),
          SwitchListTile(
            title: const Text('Show Logo'),
            value: _localSettings.showLogo,
            onChanged: (val) => setState(
                () => _localSettings = _localSettings.copyWith(showLogo: val)),
          ),
          SwitchListTile(
            title: const Text('Show Amount in Words'),
            value: _localSettings.showAmountInWords,
            onChanged: (val) => setState(() => _localSettings =
                _localSettings.copyWith(showAmountInWords: val)),
          ),
          SwitchListTile(
            title: const Text('Enable Number Formatting'),
            value: _localSettings.enableNumberFormatting,
            onChanged: (val) => setState(() => _localSettings =
                _localSettings.copyWith(enableNumberFormatting: val)),
          ),
          SwitchListTile(
            title: const Text('Show Serial Number'),
            value: _localSettings.showSrNumber,
            onChanged: (val) => setState(() =>
                _localSettings = _localSettings.copyWith(showSrNumber: val)),
          ),
          _buildSectionHeader('Text Notes'),
          _buildTextField(
            label: 'Header Note (Top)',
            initialValue: _localSettings.topNote,
            onChanged: (val) => _localSettings = _localSettings.copyWith(
                topNote:
                    val), // Field handle internal state, update object on change
            // Note: TextField onChanged doesn't auto-rebuild UI unless we set state, but here we just update model.
            // TextFields maintain their own controller state if initialValue is used only once or handled carefully.
            // Since we pass initialValue, if parent rebuilds, standard TextFormField might not update text unless controller is used.
            // But here we are NOT rebuilding parent on text change (no setState inside onChanged for text).
          ),
          _buildTextField(
            label: 'Note at Bottom',
            initialValue: _localSettings.bottomNote,
            onChanged: (val) =>
                _localSettings = _localSettings.copyWith(bottomNote: val),
          ),
          _buildTextField(
            label: 'Footer Note',
            initialValue: _localSettings.footerNote,
            onChanged: (val) =>
                _localSettings = _localSettings.copyWith(footerNote: val),
          ),
          _buildSectionHeader('Layout & Positioning'),
          _buildDropdown(
            label: 'Logo Position',
            value: _localSettings.logoPosition,
            items: const [
              DropdownMenuItem(value: 'left', child: Text('Top Left')),
              DropdownMenuItem(value: 'right', child: Text('Top Right')),
              DropdownMenuItem(value: 'center', child: Text('Center')),
            ],
            onChanged: (val) => setState(() =>
                _localSettings = _localSettings.copyWith(logoPosition: val)),
          ),
          _buildDropdown(
            label: 'Org Name Position',
            value: _localSettings.orgNamePosition,
            items: const [
              DropdownMenuItem(value: 'left', child: Text('Top Left')),
              DropdownMenuItem(value: 'right', child: Text('Top Right')),
              DropdownMenuItem(value: 'center', child: Text('Center')),
              DropdownMenuItem(
                  value: 'after_logo', child: Text('Right of Logo')),
              DropdownMenuItem(
                  value: 'before_logo', child: Text('Left of Logo')),
              DropdownMenuItem(
                  value: 'below_logo', child: Text('Bottom of Logo')),
            ],
            onChanged: (val) => setState(() =>
                _localSettings = _localSettings.copyWith(orgNamePosition: val)),
          ),
          _buildDropdown(
            label: 'Store Name Position',
            value: _localSettings.storeNamePosition,
            items: const [
              DropdownMenuItem(
                  value: 'below_org', child: Text('Below Org Name')),
              DropdownMenuItem(
                  value: 'right_of_org', child: Text('Right of Org Name')),
              DropdownMenuItem(
                  value: 'right_invoice',
                  child: Text('Right of Invoice (Top Right)')),
              DropdownMenuItem(value: 'center', child: Text('Center')),
            ],
            onChanged: (val) => setState(() => _localSettings =
                _localSettings.copyWith(storeNamePosition: val)),
          ),
          _buildDropdown(
            label: 'Address Position',
            value: _localSettings.addressPosition,
            items: const [
              DropdownMenuItem(
                  value: 'below_store', child: Text('Below Store Name')),
              DropdownMenuItem(value: 'top_right', child: Text('Top Right')),
              DropdownMenuItem(value: 'bottom', child: Text('Bottom of Page')),
            ],
            onChanged: (val) => setState(() =>
                _localSettings = _localSettings.copyWith(addressPosition: val)),
          ),
          _buildDropdown(
            label: 'Phone Position',
            value: _localSettings.phonePosition,
            items: const [
              DropdownMenuItem(
                  value: 'below_address', child: Text('Below Address')),
              DropdownMenuItem(value: 'top_right', child: Text('Top Right')),
            ],
            onChanged: (val) => setState(() =>
                _localSettings = _localSettings.copyWith(phonePosition: val)),
          ),
          _buildSectionHeader('Margins (Letterhead)'),
          _buildSlider(
            label: 'Top Margin',
            value: _localSettings.marginTop,
            min: 0,
            max: 100,
            onChanged: (val) => setState(
                () => _localSettings = _localSettings.copyWith(marginTop: val)),
          ),
          _buildSlider(
            label: 'Bottom Margin',
            value: _localSettings.marginBottom,
            min: 0,
            max: 100,
            onChanged: (val) => setState(() =>
                _localSettings = _localSettings.copyWith(marginBottom: val)),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade200,
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveValue =
        items.map((i) => i.value).contains(value) ? value : items.first.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        key: ValueKey(effectiveValue),
        initialValue: effectiveValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        ListTile(title: Text('$label: ${value.toStringAsFixed(0)}')),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
